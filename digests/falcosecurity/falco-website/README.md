# falco-website Digest

AI-optimized summaries of the [falco-website](../../../refs/falcosecurity/falco-website/) repository.

**Era**: 0.45

Use `git submodule status` from the repository root for the pinned website source revision.

## Contents

| Digest | Description | Size |
|--------|-------------|------|
| [`docs.md`](docs.md) | Core documentation (concepts, setup, rules, plugins, troubleshooting) | 54KB |
| [`blog.md`](blog.md) | Blog posts index with era markers and 0.45 release details | 33KB |
| [`about.md`](about.md) | Use cases, FAQ, ecosystem, case studies, MITRE ATT&CK | 12KB |
| [`data.md`](data.md) | Structured data (adopters, features, CLI options, config reference) | 24KB |
| [`community.md`](community.md) | Community channels, meetings, contribution guidelines, governance | 7KB |

**Total**: ~131KB

## Era Notes

- The 0.45 review covers changed documentation, the release announcement, site data and governance links. Technical corrections are sourced in each digest.
- Structured website YAML and some FAQ prose retain obsolete options; [`data.md`](data.md) and [`about.md`](about.md) distinguish that historical material from current configuration and CLI behavior.
- [`blog.md`](blog.md) contains mixed-era content; posts are marked with their respective Falco versions
- Removed in 0.44 (after deprecation in earlier releases): Legacy eBPF probe, gVisor integration, gRPC output
