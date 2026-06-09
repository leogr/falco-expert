# falco-playground Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco-playground/`](../../refs/falcosecurity/falco-playground/) | **Commit:** `8c87a0a` (March 18, 2025)

**Repository:** [falcosecurity/falco-playground](https://github.com/falcosecurity/falco-playground)
**Scope:** Infra
**Status:** Sandbox

Browser-based playground for creating, editing, and validating Falco rules using a WebAssembly build of Falco.

---

> **IMPORTANT STATUS NOTICE**
>
> This project is **experimental and not actively curated** (~3 years without major updates). The deployed application at [play.falco.org](https://play.falco.org/) runs **Falco 0.37.1** (wasm), which is significantly behind the current era (0.43).
>
> **Why it remains relevant:**
> 1. **User perspective**: Demonstrates an interactive playground for rule authors - a valuable UX pattern for future development
> 2. **Technical proof-of-concept**: Proves Falco can run in WebAssembly within a browser
> 3. **Wasm build validation**: The Falco wasm build is automatically built by CI (though not officially supported), and this project validates that build works
>
> **Current limitations:**
> - Rule syntax and available fields may differ from current Falco version
> - No active maintenance or feature development
> - Should not be used as reference for current Falco capabilities

---

## Overview

Falco Playground is a client-side web application that allows users to write and validate Falco rules directly in the browser. It loads a WebAssembly build of Falco and runs rule validation entirely client-side without any backend server.

**Live deployment:** https://play.falco.org/ (based on Falco 0.37.1)

**Key features:**
- Monaco-based code editor with Falco rule syntax highlighting
- Real-time rule validation using Falco's `--validate` mode
- Support for testing rules against `.scap` capture files
- Entirely client-side - no data leaves the browser
- Example rules included for learning

**Source:** [`readme.md`](../../refs/falcosecurity/falco-playground/readme.md)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Falco Playground Architecture                       │
└──────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────────┐
                              │   Browser           │
                              │                     │
                              │ ┌─────────────────┐ │
                              │ │  React App      │ │
                              │ │  (TypeScript)   │ │
                              │ └────────┬────────┘ │
                              │          │          │
                              │          ▼          │
                              │ ┌─────────────────┐ │
                              │ │  Monaco Editor  │ │
                              │ │  (Rule editing) │ │
                              │ └────────┬────────┘ │
                              │          │          │
                              │          ▼          │
                              │ ┌─────────────────┐ │
                              │ │  falco.wasm     │ │  ◄── WebAssembly
                              │ │  (Emscripten)   │ │      build of Falco
                              │ └────────┬────────┘ │
                              │          │          │
                              │          ▼          │
                              │ ┌─────────────────┐ │
                              │ │  Validation     │ │
                              │ │  Results        │ │
                              │ └─────────────────┘ │
                              └─────────────────────┘
                                        │
                                        ▼
                              No backend - all processing
                              happens in the browser
```

**Source:** [`src/Hooks/UseWasm.tsx`](../../refs/falcosecurity/falco-playground/src/Hooks/UseWasm.tsx)

## How It Works

### WebAssembly Integration

The playground uses Falco compiled to WebAssembly via Emscripten:

```typescript
// UseWasm.tsx - Loading Falco in the browser
const module: EmscriptenModule = await Module({
  noInitialRun: true,
  thisProgram: "falco",
  // ...
});

// Writing rules and running validation
module.FS.writeFile("rule.yaml", code);
module.callMain(["--validate", "rule.yaml", "-o", "json_output=true", ...]);
```

**Validation mode:**
```
falco --validate rule.yaml -o json_output=true -o log_level=debug -v
```

**Replay mode (with .scap file):**
```
falco -r rule.yaml -o engine.kind=replay -o engine.replay.capture_file=capture.scap
```

**Source:** [`src/Hooks/UseWasm.tsx`](../../refs/falcosecurity/falco-playground/src/Hooks/UseWasm.tsx)

### Wasm Artifact Source

The wasm build is downloaded from:
```
https://download.falco.org/packages/wasm-dev/falco-0.37.1-wasm.tar.gz
```

This artifact contains:
- `falco.wasm` - The WebAssembly binary
- `falco.js` - Emscripten-generated JavaScript glue code

**Source:** [`falco_stable_url.txt`](../../refs/falcosecurity/falco-playground/falco_stable_url.txt)

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | React 18 + TypeScript |
| Build tool | Vite |
| Code editor | Monaco Editor |
| State management | Redux Toolkit |
| UI framework | Ant Design |
| Testing | Cypress |
| Deployment | AWS S3 + CloudFront |

**Source:** [`package.json`](../../refs/falcosecurity/falco-playground/package.json)

## Features

### Rule Editor
- Monaco-based editor with YAML support
- Falco rule schema validation
- Syntax highlighting for Falco rule language

### Rule Validation
- Validates rule syntax and structure
- Reports errors and warnings
- JSON-formatted output

### Capture File Testing
- Upload `.scap` capture files
- Run rules against captured events
- See which rules would trigger

### Example Rules
Built-in examples demonstrating:
- Shell configuration file access detection
- Directory traversal attack detection
- SSH information read detection

**Source:** [`src/data/examples.ts`](../../refs/falcosecurity/falco-playground/src/data/examples.ts)

## Deployment

The application is deployed to AWS S3 and served via CloudFront:

| Setting | Value |
|---------|-------|
| S3 Bucket | `falco-playground` |
| Region | `eu-west-1` |
| Distribution | CloudFront CDN |
| URL | https://play.falco.org/ |

**Release process:**
1. Create GitHub release
2. CI downloads Falco wasm artifact
3. Builds React application
4. Uploads to S3, invalidates CloudFront cache

**Source:** [`.github/workflows/release.yaml`](../../refs/falcosecurity/falco-playground/.github/workflows/release.yaml)

## Falco Wasm Build

> **Note:** The Falco WebAssembly build is **not officially supported** but is automatically built by Falco's CI pipeline. This project serves as validation that the wasm build works.

**Wasm build location in Falco CI:**
1. Go to https://github.com/falcosecurity/falco/actions/workflows/ci.yml
2. Select a successful workflow
3. Download `falco-*-wasm.tar.gz` artifact

**Current deployed version:** Falco 0.37.1

**Source:** [`readme.md`](../../refs/falcosecurity/falco-playground/readme.md)

## Local Development

```shell
# Install dependencies
npm install

# Download Falco wasm artifacts (from Falco CI or stable URL)
# Move falco.wasm to public/
# Move falco.js to src/Hooks/

# Start development server
npm run dev

# Run tests
npm run cy:run
```

**Source:** [`readme.md`](../../refs/falcosecurity/falco-playground/readme.md)

## Future Potential

While currently unmaintained, this project demonstrates valuable patterns:

1. **Interactive rule development** - Rules can be validated instantly without Falco installation
2. **Educational tool** - Learn Falco rule syntax in a safe environment
3. **Browser-based security tooling** - Proves Falco can run client-side
4. **Capture file analysis** - Test rules against real event captures

**Potential improvements (if revived):**
- Update to current Falco version
- Add rule suggestions/autocomplete
- Include more example rules
- Add rule sharing functionality

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, setup | [`readme.md`](../../refs/falcosecurity/falco-playground/readme.md) |
| Wasm integration | [`src/Hooks/UseWasm.tsx`](../../refs/falcosecurity/falco-playground/src/Hooks/UseWasm.tsx) |
| Example rules | [`src/data/examples.ts`](../../refs/falcosecurity/falco-playground/src/data/examples.ts) |
| Falco version | [`falco_stable_url.txt`](../../refs/falcosecurity/falco-playground/falco_stable_url.txt) |
| Release workflow | [`.github/workflows/release.yaml`](../../refs/falcosecurity/falco-playground/.github/workflows/release.yaml) |

## Related Documentation

- [`falco/rule-language.md`](falco/rule-language.md) - Current rule language specification
- [`rules.md`](rules.md) - Official Falco rules
- [`falco/cli-reference.md`](falco/cli-reference.md) - Falco CLI including `--validate`
- [`libs/scap-file-format.md`](libs/scap-file-format.md) - `.scap` capture file format
