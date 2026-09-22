# Blog input prompt

A bullet list of user-facing updates from the milestone, prepared as the prompt for a separate writing session (the maintainer or a writer drafts the post; this skill never opens or edits blog content on its own). Every bullet carries its source PR or release so the claims stay within what the source says. Embargoed items stay out; the maintainer adds them after the advisory is public. Release date, contributor list, and counts are filled on release day from the generated changelog.

```markdown
# <Component> <version> release blog post: input bullets

Mirror the structure of the previous release post: a TL;DR with anchors, one section per major feature, then Drivers, Plugins, Rules, Kubernetes, Breaking changes, Try it out, Stay connected. Keep every claim within its source. No candidate mentions; the version is `<version>` everywhere.

## Component versions

| Component | <version> | <previous-version> |
|---|---|---|
| engine | | |
| libs | | |
| driver | | |
| falcoctl | | |
| rules (stable / sandbox / incubating) | | |
| <plugin> (bundled) | | |
| k8smeta plugin | | |
| Helm chart | | |
| k8s-metacollector | | |

## Major features and improvements

- <feature, one or two sentences, the user-visible effect; breaking flag and engine bump if any> 👉 <pr-url>

## Packaging and installation

- <change> 👉 <pr-url>

## Security hardening

- <change> 👉 <pr-url>

## Drivers

- <change; action required for upgrades if any> 👉 <pr-url>
- Prebuilt drivers: <coverage at release time, or the warning box to reuse>

## Plugins

- <plugin> `<version>` (bundled): <changes> 👉 <release-url>

## Rules

- <ruleset> `<version>`: <changes> 👉 <release-url>

## Kubernetes

- Helm chart `<chart-version>`: <changes, pins, subchart constraints> 👉 <changelog path or pr-urls>
- <operator or metacollector notes; keep conditional until their tags exist>

## Breaking changes and action required

- <one line each, with the source>

## Numbers to fill on release day

- merged PRs in the milestone (with and without release notes), contributors from the generated changelog, bugs closed

## Notes for the writer

- Link the updated documentation pages once they are live
- Keep items whose tags do not exist yet conditional
```

Editorial checks before handing the prompt over: every URL resolves; every version in the table matches the pins at the final tag; no candidate names; no embargoed content.
