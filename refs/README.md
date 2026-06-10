# References

This folder contains data sources used as input to construct the Falco knowledge base.

## Contents

Git submodules and other reference materials pointing to correct versions for the current era (0.44).

### [`falcosecurity/`](falcosecurity/)

Mirrors the [falcosecurity](https://github.com/falcosecurity) GitHub organization structure (official Falco project organization).

| Repository | Description |
|------------|-------------|
| [`evolution/`](falcosecurity/evolution/) | Project governance, repository mapping, maintainers |
| [`falco-website/`](falcosecurity/falco-website/) | Source code for [falco.org](https://falco.org) |

## Guidelines

- **Do not modify** contents within the same era
- Update submodules only when transitioning to a new era
- All contents here are referenced by [`digests/`](../digests/) and [`specs/`](../specs/)
