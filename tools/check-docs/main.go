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
	repoRoot     = mustRepoRoot()
	refsRoot     = filepath.Join(repoRoot, "refs")
	codeFenceRE  = regexp.MustCompile("(?s)```.*?```")
	linkRE       = regexp.MustCompile(`!?\[([^\]]+)\]\(([^)]+)\)`)
	countLabelRE = regexp.MustCompile(`^(\d+)\s+digests?$`)
	upperTokenRE = regexp.MustCompile(`^[A-Z_]+$`)
)

type linkRef struct {
	line     int
	label    string
	target   string
	resolved string
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "usage: %s <md-links|refs-paths|index-drift|all>\n", filepath.Base(os.Args[0]))
		os.Exit(2)
	}

	check := os.Args[1]
	if !slices.Contains([]string{"md-links", "refs-paths", "index-drift", "all"}, check) {
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
			}
		}
	}
	return reportIssues("check-md-links", issues)
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
	expectedCounts := map[string]int{
		"falco/":         countMarkdownDigests(filepath.Join(filepath.Dir(digestsIndex), "falco")),
		"falcosidekick/": countMarkdownDigests(filepath.Join(filepath.Dir(digestsIndex), "falcosidekick")),
		"falco-website/": countMarkdownDigests(filepath.Join(filepath.Dir(digestsIndex), "falco-website")),
		"libs/":          countMarkdownDigests(filepath.Join(filepath.Dir(digestsIndex), "libs")),
		"plugins/":       countMarkdownDigests(filepath.Join(filepath.Dir(digestsIndex), "plugins")) + 1,
		"test-infra/":    countMarkdownDigests(filepath.Join(filepath.Dir(digestsIndex), "test-infra")),
	}
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

	text := blankCode(string(content))
	matches := linkRE.FindAllStringSubmatchIndex(text, -1)
	refs := make([]linkRef, 0, len(matches))

	for _, match := range matches {
		label := strings.TrimSpace(text[match[2]:match[3]])
		target := strings.TrimSpace(text[match[4]:match[5]])
		if strings.HasPrefix(target, "http://") || strings.HasPrefix(target, "https://") || strings.HasPrefix(target, "mailto:") || strings.HasPrefix(target, "#") {
			continue
		}
		if isPlaceholderTarget(target) {
			continue
		}

		targetPath, _, _ := strings.Cut(target, "#")
		targetPath = strings.TrimSpace(targetPath)
		if targetPath == "" {
			continue
		}

		resolved := filepath.Clean(filepath.Join(filepath.Dir(path), targetPath))
		line := 1 + strings.Count(text[:match[0]], "\n")
		refs = append(refs, linkRef{
			line:     line,
			label:    label,
			target:   target,
			resolved: resolved,
		})
	}

	return refs
}

func blankCode(text string) string {
	return codeFenceRE.ReplaceAllStringFunc(text, func(match string) string {
		return strings.Repeat("\n", strings.Count(match, "\n"))
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
