# Commit message with a single sign-off

Commit messages are written to a file and passed with `git commit -F <file>`. Never use `-s`: it signs with the configured e-mail, which may differ from the maintainer's open-source identity, and DCO requires author == sign-off. Author and committer are set for the one command (`git -c user.name=... -c user.email=...`). Exactly one `Signed-off-by:` trailer, no AI attribution trailer unless the maintainer allows it. Conventional Commits form, scope in parentheses, `!` for breaking changes.

```text
<type>(<scope>): <description>

<optional body: the mechanism, one short paragraph>

Signed-off-by: <Name> <<e-mail>>
```

Patterns used across a release:

| Change | Message |
|---|---|
| Component pin | `build(<component>): bump <component> to <version>` (one commit per component; the checksum change rides the same commit) |
| Changelog | `docs: add <Component> \`<version>\` changelogs to \`CHANGELOG.md\`` |
| Chart release | `chore(chart): release <chart-version> for <Component> <version>` |
| Chart candidate | `chore(chart): release <chart-candidate> for <Component> <candidate>` |
| Infra bump | `chore(config/applications): testing <Component> <candidate>` or `chore(config/applications): update <Component> to <version>` |
| Workflow pin fix | `ci(release): <what the fix does>` |
| Website snapshot | `chore(config): archive \`<previous-version>\`` |
| Website version switch | `chore(config): bump <Component> (\`<version>\`) and latest rules versions` |
| Website generated pages | `feat(content): update generated pages for <Component> \`<version>\`` |
| Release-branch protection | `update(config): protect \`<release-branch>\` branch of \`<repo>\`` |

Cherry-picks keep the original message, author, and sign-off; only the committer identity is the maintainer's, no `-x` line.

Before pushing a prepared commit, a gated script verifies: exactly one commit over the base, author and committer equal the mandate identity, exactly one sign-off line matching it, no unexpected trailers, the expected file set, and the base head unchanged since the dry run.
