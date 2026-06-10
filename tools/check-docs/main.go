package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strings"
)

var (
	repoRoot         = mustRepoRoot()
	refsRoot         = filepath.Join(repoRoot, "refs")
	digestsRoot      = filepath.Join(repoRoot, "digests")
	specsRoot        = filepath.Join(repoRoot, "specs")
	codeFenceRE      = regexp.MustCompile("(?s)```.*?```")
	linkRE           = regexp.MustCompile(`!?\[([^\]]+)\]\(([^)]+)\)`)
	countLabelRE     = regexp.MustCompile(`^(\d+)\s+digests?$`)
	upperTokenRE     = regexp.MustCompile(`^[A-Z_]+$`)
	headingRE        = regexp.MustCompile(`(?m)^#{1,6}[ \t]+(.+?)[ \t]*$`)
	htmlAnchorRE     = regexp.MustCompile(`<a\s+(?:name|id)="([^"]+)"`)
	inlineCodeRE     = regexp.MustCompile("`([^`]*)`")
	slugStripRE      = regexp.MustCompile(`[^\p{L}\p{N}\p{M} _-]`)
	looseSlugStripRE = regexp.MustCompile(`[^a-z0-9]`)
	lineAnchorRE     = regexp.MustCompile(`^L\d+`)
	// Accepts the canonical `## Sources` heading plus transitional legacy
	// variants (see TODOs: "Source section heading normalization").
	sourcesHeadingRE = regexp.MustCompile(`(?m)^#{2,3} (\d+\. )?(Sources|Source Files( Reference)?|Source References)\s*$`)
)

type linkRef struct {
	line     int
	label    string
	target   string
	resolved string
	fragment string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "usage: %s <md-links|refs-paths|index-drift|sources|all>\n", filepath.Base(os.Args[0]))
		os.Exit(2)
	}

	check := os.Args[1]
	if !slices.Contains([]string{"md-links", "refs-paths", "index-drift", "sources", "all"}, check) {
		fmt.Fprintf(os.Stderr, "unknown check %q\n", check)
		os.Exit(2)
	}

	failures := 0
	if check == "md-links" || check == "all" {
		failures += checkMDLinks()
	}
	if check == "refs-paths" || check == "all" {
		failures += checkRefsPaths()
	}
	if check == "index-drift" || check == "all" {
		failures += checkIndexDrift()
	}
	if check == "sources" || check == "all" {
		failures += checkSources()
	}

	if failures != 0 {
		fmt.Printf("documentation checks failed with %d issue(s)\n", failures)
		os.Exit(1)
	}

	fmt.Println("documentation checks passed")
}

func checkMDLinks() int {
	issues := []string{}
	for _, path := range authoredMarkdownFiles() {
		for _, ref := range iterLocalLinks(path) {
			if !pathExists(ref.resolved) {
				issues = append(issues, fmt.Sprintf("%s:%d: missing local link target `%s`", rel(path), ref.line, ref.target))
				continue
			}
			if isWithin(path, digestsRoot) && (ref.resolved == specsRoot || isWithin(ref.resolved, specsRoot)) {
				issues = append(issues, fmt.Sprintf("%s:%d: digest links into specs/ (`%s`); link direction is one-way (specs -> digests, never the reverse)", rel(path), ref.line, ref.target))
			}
			if hasCheckableAnchor(ref) && !anchorExists(ref.resolved, ref.fragment) {
				issues = append(issues, fmt.Sprintf("%s:%d: missing anchor `#%s` in `%s`", rel(path), ref.line, ref.fragment, rel(ref.resolved)))
			}
		}
	}
	return reportIssues("check-md-links", issues)
}

// hasCheckableAnchor reports whether the link carries a fragment that should
// be validated against the target's headings. Fragments into refs/ (upstream
// content) and GitHub line anchors (#L123) are skipped.
func hasCheckableAnchor(ref linkRef) bool {
	return ref.fragment != "" &&
		strings.HasSuffix(strings.ToLower(ref.resolved), ".md") &&
		!isWithin(ref.resolved, refsRoot) &&
		!lineAnchorRE.MatchString(ref.fragment)
}

func checkRefsPaths() int {
	issues := []string{}
	for _, path := range authoredMarkdownFiles() {
		for _, ref := range iterLocalLinks(path) {
			if ref.resolved == refsRoot || isWithin(ref.resolved, refsRoot) {
				if !pathExists(ref.resolved) {
					issues = append(issues, fmt.Sprintf("%s:%d: stale refs path `%s`", rel(path), ref.line, ref.target))
				}
			}
		}
	}
	return reportIssues("check-refs-paths", issues)
}

func checkIndexDrift() int {
	issues := []string{}

	refsIndex := filepath.Join(repoRoot, "refs", "falcosecurity", "README.md")
	refsExpected := expectedRefsFalcosecurity()
	refsListed := listedChildren(refsIndex, filepath.Dir(refsIndex))
	addSetDiffIssues(&issues, refsIndex, refsExpected, refsListed)

	digestsIndex := filepath.Join(repoRoot, "digests", "falcosecurity", "README.md")
	digestsExpected := expectedDigestsFalcosecurity()
	digestsListed := listedChildren(digestsIndex, filepath.Dir(digestsIndex))
	addSetDiffIssues(&issues, digestsIndex, digestsExpected, digestsListed)

	counts := advertisedDigestCounts(digestsIndex, filepath.Dir(digestsIndex))
	expectedCounts := expectedDigestCounts(filepath.Dir(digestsIndex))
	for key, expected := range expectedCounts {
		advertised, ok := counts[key]
		if !ok {
			issues = append(issues, fmt.Sprintf("%s: missing digest count label for `%s`", rel(digestsIndex), key))
			continue
		}
		if advertised != expected {
			issues = append(issues, fmt.Sprintf("%s: `%s` advertises %d digests but filesystem has %d", rel(digestsIndex), key, advertised, expected))
		}
	}

	skillsIndex := filepath.Join(repoRoot, "skills", "README.md")
	skillsExpected := expectedSkills()
	skillsListed := listedChildren(skillsIndex, filepath.Dir(skillsIndex))
	addSetDiffIssues(&issues, skillsIndex, skillsExpected, skillsListed)

	return reportIssues("check-index-drift", issues)
}

// checkSources verifies that every content digest and spec ends with a
// sources section (AGENTS.md "Digest Creation" rule 3). Navigation hub
// README.md files are exempt.
func checkSources() int {
	issues := []string{}

	files := map[string]struct{}{}
	collectMarkdownFiles(files, digestsRoot, false)
	collectMarkdownFiles(files, specsRoot, false)

	paths := make([]string, 0, len(files))
	for path := range files {
		paths = append(paths, path)
	}
	slices.Sort(paths)

	for _, path := range paths {
		if filepath.Base(path) == "README.md" {
			continue
		}
		content, err := os.ReadFile(path)
		if err != nil {
			issues = append(issues, fmt.Sprintf("%s: unreadable: %v", rel(path), err))
			continue
		}
		if !sourcesHeadingRE.MatchString(blankCode(string(content))) {
			issues = append(issues, fmt.Sprintf("%s: missing `## Sources` section", rel(path)))
		}
	}

	return reportIssues("check-sources", issues)
}

func authoredMarkdownFiles() []string {
	files := map[string]struct{}{}

	rootDocs := []string{
		"AGENTS.md",
		"README.md",
		"WORKFLOWS.md",
		"TODOs.md",
		filepath.Join("refs", "README.md"),
		filepath.Join("refs", "falcosecurity", "README.md"),
	}
	for _, relPath := range rootDocs {
		absPath := filepath.Join(repoRoot, relPath)
		if pathExists(absPath) {
			files[absPath] = struct{}{}
		}
	}

	collectMarkdownFiles(files, filepath.Join(repoRoot, "agents"), false)
	collectMarkdownFiles(files, filepath.Join(repoRoot, "digests"), false)
	collectMarkdownFiles(files, filepath.Join(repoRoot, "specs"), false)
	collectMarkdownFiles(files, filepath.Join(repoRoot, "skills"), true)

	paths := make([]string, 0, len(files))
	for path := range files {
		paths = append(paths, path)
	}
	slices.Sort(paths)
	return paths
}

func collectMarkdownFiles(out map[string]struct{}, root string, excludeWorkspace bool) {
	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if excludeWorkspace && hasWorkspaceComponent(rel(path)) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		if !d.IsDir() && strings.HasSuffix(d.Name(), ".md") {
			out[path] = struct{}{}
		}
		return nil
	})
}

func hasWorkspaceComponent(path string) bool {
	for _, part := range strings.Split(path, string(os.PathSeparator)) {
		if strings.HasSuffix(part, "-workspace") {
			return true
		}
	}
	return false
}

func iterLocalLinks(path string) []linkRef {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil
	}

	text := blankInlineCode(blankCode(string(content)))
	matches := linkRE.FindAllStringSubmatchIndex(text, -1)
	refs := make([]linkRef, 0, len(matches))

	for _, match := range matches {
		label := strings.TrimSpace(text[match[2]:match[3]])
		target := strings.TrimSpace(text[match[4]:match[5]])
		if strings.HasPrefix(target, "http://") || strings.HasPrefix(target, "https://") || strings.HasPrefix(target, "mailto:") {
			continue
		}
		if isPlaceholderTarget(target) {
			continue
		}

		line := 1 + strings.Count(text[:match[0]], "\n")

		// Anchor-only links resolve to the containing file itself.
		if strings.HasPrefix(target, "#") {
			refs = append(refs, linkRef{
				line:     line,
				label:    label,
				target:   target,
				resolved: path,
				fragment: strings.TrimPrefix(target, "#"),
			})
			continue
		}

		targetPath, fragment, _ := strings.Cut(target, "#")
		targetPath = strings.TrimSpace(targetPath)
		if targetPath == "" {
			continue
		}

		resolved := filepath.Clean(filepath.Join(filepath.Dir(path), targetPath))
		refs = append(refs, linkRef{
			line:     line,
			label:    label,
			target:   target,
			resolved: resolved,
			fragment: strings.TrimSpace(fragment),
		})
	}

	return refs
}

var headingSlugCache = map[string]map[string]struct{}{}

// anchorExists reports whether fragment matches a heading anchor (GitHub
// slug) or explicit HTML anchor in the markdown file at path. A lenient
// fallback comparison (alphanumerics and hyphens only) absorbs slugging
// corner cases such as emoji in headings.
func anchorExists(path, fragment string) bool {
	slugs, ok := headingSlugCache[path]
	if !ok {
		slugs = headingSlugs(path)
		headingSlugCache[path] = slugs
	}

	frag := strings.ToLower(fragment)
	if _, ok := slugs[frag]; ok {
		return true
	}
	loose := looseSlugStripRE.ReplaceAllString(frag, "")
	for slug := range slugs {
		if looseSlugStripRE.ReplaceAllString(slug, "") == loose {
			return true
		}
	}
	return false
}

func headingSlugs(path string) map[string]struct{} {
	slugs := map[string]struct{}{}
	content, err := os.ReadFile(path)
	if err != nil {
		return slugs
	}

	text := blankCode(string(content))
	seen := map[string]int{}
	for _, match := range headingRE.FindAllStringSubmatch(text, -1) {
		slug := githubSlug(match[1])
		// GitHub disambiguates repeated headings with -1, -2, ... suffixes.
		if n := seen[slug]; n > 0 {
			slugs[fmt.Sprintf("%s-%d", slug, n)] = struct{}{}
		} else {
			slugs[slug] = struct{}{}
		}
		seen[slug]++
	}
	for _, match := range htmlAnchorRE.FindAllStringSubmatch(text, -1) {
		slugs[strings.ToLower(match[1])] = struct{}{}
	}
	return slugs
}

// githubSlug converts a heading text into its GitHub-generated anchor:
// inline markup stripped, lowercased, punctuation removed, spaces hyphenated.
func githubSlug(heading string) string {
	s := strings.TrimSpace(heading)
	s = inlineCodeRE.ReplaceAllString(s, "$1")
	s = linkRE.ReplaceAllString(s, "$1")
	s = strings.ToLower(s)
	s = slugStripRE.ReplaceAllString(s, "")
	s = strings.ReplaceAll(s, " ", "-")
	return s
}

func blankCode(text string) string {
	return codeFenceRE.ReplaceAllStringFunc(text, func(match string) string {
		return strings.Repeat("\n", strings.Count(match, "\n"))
	})
}

// blankInlineCode blanks `inline code` spans (preserving offsets and line
// numbers) so that example links inside them are not treated as real links.
func blankInlineCode(text string) string {
	return inlineCodeRE.ReplaceAllStringFunc(text, func(match string) string {
		blanked := []rune(match)
		for i, r := range blanked {
			if r != '\n' {
				blanked[i] = ' '
			}
		}
		return string(blanked)
	})
}

func isPlaceholderTarget(target string) bool {
	stripped := strings.TrimSpace(target)
	if strings.Contains(stripped, "{{") || strings.Contains(stripped, "}}") || strings.Contains(stripped, "<") || strings.Contains(stripped, ">") || strings.Contains(stripped, "...") {
		return true
	}
	return upperTokenRE.MatchString(stripped)
}

func listedChildren(indexPath, baseDir string) map[string]struct{} {
	children := map[string]struct{}{}
	for _, ref := range iterLocalLinks(indexPath) {
		parent := filepath.Dir(ref.resolved)
		if parent != baseDir {
			continue
		}

		info, err := os.Stat(ref.resolved)
		if err != nil {
			continue
		}
		if info.IsDir() {
			children[filepath.Base(ref.resolved)+"/"] = struct{}{}
			continue
		}
		if filepath.Base(ref.resolved) != "README.md" {
			children[filepath.Base(ref.resolved)] = struct{}{}
		}
	}
	return children
}

func expectedRefsFalcosecurity() map[string]struct{} {
	base := filepath.Join(repoRoot, "refs", "falcosecurity")
	return expectedDirs(base, nil)
}

func expectedDigestsFalcosecurity() map[string]struct{} {
	base := filepath.Join(repoRoot, "digests", "falcosecurity")
	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}

	expected := map[string]struct{}{}
	for _, entry := range entries {
		name := entry.Name()
		if name == "README.md" {
			continue
		}
		if entry.IsDir() {
			expected[name+"/"] = struct{}{}
			continue
		}
		if filepath.Ext(name) == ".md" {
			expected[name] = struct{}{}
		}
	}
	return expected
}

func expectedSkills() map[string]struct{} {
	base := filepath.Join(repoRoot, "skills")
	return expectedDirs(base, func(path string, d fs.DirEntry) bool {
		if strings.HasSuffix(d.Name(), "-workspace") {
			return false
		}
		info, err := os.Stat(filepath.Join(path, "SKILL.md"))
		return err == nil && !info.IsDir()
	})
}

func expectedDirs(base string, include func(path string, d fs.DirEntry) bool) map[string]struct{} {
	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}

	expected := map[string]struct{}{}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		path := filepath.Join(base, entry.Name())
		if include != nil && !include(path, entry) {
			continue
		}
		expected[entry.Name()+"/"] = struct{}{}
	}
	return expected
}

// expectedDigestCounts derives, from the filesystem, the digest count each
// subdirectory group must advertise in the index. A sibling `<name>.md`
// overview file (e.g., plugins.md next to plugins/) counts toward its group.
func expectedDigestCounts(base string) map[string]int {
	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}

	expected := map[string]int{}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		count := countMarkdownDigests(filepath.Join(base, entry.Name()))
		if pathExists(filepath.Join(base, entry.Name()+".md")) {
			count++
		}
		expected[entry.Name()+"/"] = count
	}
	return expected
}

func countMarkdownDigests(dir string) int {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}

	count := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if name != "README.md" && filepath.Ext(name) == ".md" {
			count++
		}
	}
	return count
}

func advertisedDigestCounts(indexPath, baseDir string) map[string]int {
	counts := map[string]int{}
	for _, ref := range iterLocalLinks(indexPath) {
		matches := countLabelRE.FindStringSubmatch(ref.label)
		if matches == nil {
			continue
		}
		info, err := os.Stat(ref.resolved)
		if err != nil || !info.IsDir() || filepath.Dir(ref.resolved) != baseDir {
			continue
		}
		var count int
		_, err = fmt.Sscanf(matches[1], "%d", &count)
		if err != nil {
			continue
		}
		counts[filepath.Base(ref.resolved)+"/"] = count
	}
	return counts
}

func addSetDiffIssues(issues *[]string, indexPath string, expected, listed map[string]struct{}) {
	missing := sortedSetDiff(expected, listed)
	extra := sortedSetDiff(listed, expected)
	if len(missing) > 0 {
		*issues = append(*issues, fmt.Sprintf("%s: missing entries: %s", rel(indexPath), strings.Join(missing, ", ")))
	}
	if len(extra) > 0 {
		*issues = append(*issues, fmt.Sprintf("%s: unexpected entries: %s", rel(indexPath), strings.Join(extra, ", ")))
	}
}

func sortedSetDiff(left, right map[string]struct{}) []string {
	diff := []string{}
	for key := range left {
		if _, ok := right[key]; !ok {
			diff = append(diff, key)
		}
	}
	slices.Sort(diff)
	return diff
}

func reportIssues(title string, issues []string) int {
	if len(issues) == 0 {
		fmt.Printf("%s: OK\n", title)
		return 0
	}

	fmt.Printf("%s: FAILED\n", title)
	for _, issue := range issues {
		fmt.Printf("  - %s\n", issue)
	}
	return len(issues)
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func isWithin(path, base string) bool {
	relPath, err := filepath.Rel(base, path)
	return err == nil && relPath != "." && relPath != ".." && !strings.HasPrefix(relPath, ".."+string(os.PathSeparator))
}

func rel(path string) string {
	relPath, err := filepath.Rel(repoRoot, path)
	if err != nil {
		return path
	}
	return relPath
}

func mustRepoRoot() string {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		panic("unable to resolve checker source path")
	}
	root, err := filepath.Abs(filepath.Join(filepath.Dir(file), "..", ".."))
	if err != nil {
		panic(err)
	}
	return root
}
