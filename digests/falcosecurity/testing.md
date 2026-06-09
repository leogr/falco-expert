# testing

Regression test suite for Falco and other tools in its ecosystem.

**Repository:** [falcosecurity/testing](https://github.com/falcosecurity/testing)
**Commit:** `2f1fba01` (February 5, 2026)
**Scope:** Infra
**Status:** Incubating

## Overview

The testing repository provides an end-to-end, black-box testing suite for Falco and its ecosystem tools. It emulates typical user patterns to validate both individual tools and their integration.

Key characteristics:
- **Go-based**: Tests are defined as code with Go as the only dependency
- **Code-generated artifacts**: Test binaries and supporting files are generated via `go generate ./...`
- **GitHub Action**: Provides a composite action for CI integration
- **Ported legacy tests**: Contains 1-1 porting of legacy Python regression tests from falcosecurity/falco

**Source:** [`README.md`](../../refs/falcosecurity/testing/README.md)

## Architecture

### Test Binaries

The suite produces multiple test binaries, each targeting a specific component:

| Binary | Target | Description |
|--------|--------|-------------|
| `falco.test` | Falco | Main Falco executable regression tests |
| `falcoctl.test` | falcoctl | Falco CLI tool tests |
| `k8saudit.test` | k8saudit plugin | Kubernetes audit plugin tests |
| `dummy.test` | dummy plugin | Dummy plugin tests |
| `falco-driver-loader.test` | drivers | Driver loader tests (requires kernel headers) |

**Source:** [`README.md`](../../refs/falcosecurity/testing/README.md), [`action.yml:88-111`](../../refs/falcosecurity/testing/action.yml)

### Package Structure

| Package | Purpose |
|---------|---------|
| `pkg/run` | Runner interface and implementations (executable, Docker) |
| `pkg/falco` | Falco test harness with options and output assertions |
| `pkg/falcoctl` | Falcoctl test harness |
| `tests/` | Test implementations organized by component |
| `tests/data/` | Test data generation (rules, configs, captures, outputs) |

**Source:** [`pkg/`](../../refs/falcosecurity/testing/pkg/), [`tests/`](../../refs/falcosecurity/testing/tests/)

### Runner Interface

The `Runner` interface abstracts how executables are run:

```go
// Runner runs Falco with a given set of options
type Runner interface {
    // Run runs Falco with the given options and returns when it finishes its
    // execution or when the context deadline is exceeded.
    Run(ctx context.Context, options ...RunnerOption) error
    // WorkDir return the absolute path to the working directory assigned
    // to the runner.
    WorkDir() string
}
```

**Runner implementations:**
- `ExecutableRunner`: Runs local executable binaries
- `DockerRunner`: Runs executables within Docker containers

**Source:** [`pkg/run/runner.go:39-47`](../../refs/falcosecurity/testing/pkg/run/runner.go), [`pkg/run/executable.go`](../../refs/falcosecurity/testing/pkg/run/executable.go), [`pkg/run/docker.go`](../../refs/falcosecurity/testing/pkg/run/docker.go)

### Runner Options

```go
WithFiles(files ...FileAccessor)     // Add files for execution
WithArgs(args ...string)             // CLI arguments
WithStdout(writer io.Writer)         // Capture stdout
WithStderr(writer io.Writer)         // Capture stderr
WithEnvVars(vars map[string]string)  // Environment variables
```

**Source:** [`pkg/run/runner.go:49-82`](../../refs/falcosecurity/testing/pkg/run/runner.go)

## Falco Test Harness

### Test Function

The `falco.Test()` function runs Falco with test options and returns a `TestOutput`:

```go
func Test(runner run.Runner, options ...TestOption) *TestOutput
```

Default behaviors:
- Uses `/etc/falco/falco.yaml` as config
- Enforces debug logging on stderr
- Enables stdout output
- Sets 5-minute maximum duration

**Source:** [`pkg/falco/tester.go:69-115`](../../refs/falcosecurity/testing/pkg/falco/tester.go)

### Test Options

| Option | Purpose |
|--------|---------|
| `WithRules(rules ...FileAccessor)` | Load rules files via `-r` |
| `WithConfig(f FileAccessor)` | Use config file via `-c` |
| `WithCaptureFile(f FileAccessor)` | Replay capture file via `engine.kind=replay` |
| `WithOutputJSON()` | Enable JSON output format |
| `WithRulesValidation(rules ...FileAccessor)` | Validate rules via `-V` |
| `WithArgs(args ...string)` | Pass additional CLI arguments |
| `WithEnabledTags(tags ...string)` | Enable rules by tag |
| `WithDisabledTags(tags ...string)` | Disable rules by tag |
| `WithDisabledRules(rules ...string)` | Disable specific rules |
| `WithMinRulePriority(priority string)` | Set minimum rule priority |
| `WithContextDeadline(duration)` | Set maximum run duration |
| `WithStopAfter(duration)` | Stop Falco after duration (`-M`) |
| `WithAllEvents()` | Enable all syscalls via `base_syscalls.all=true` |
| `WithPrometheusMetrics()` | Enable Prometheus metrics endpoint |
| `WithEnvVars(vars map[string]string)` | Set environment variables |

**Source:** [`pkg/falco/tester_options.go`](../../refs/falcosecurity/testing/pkg/falco/tester_options.go)

### Test Output

The `TestOutput` type provides methods to analyze test results:

```go
// Error handling
Err() error                    // Returns error if Falco run failed
ExitCode() int                 // Returns Falco exit code
DurationExceeded() bool        // True if context deadline exceeded

// Output access
Stdout() string                // Raw stdout
Stderr() string                // Raw stderr
StdoutJSON() map[string]interface{}  // Parsed JSON stdout
```

**Source:** [`pkg/falco/tester_output.go`](../../refs/falcosecurity/testing/pkg/falco/tester_output.go)

### Detection Assertions

When using `WithOutputJSON()`, detection assertions are available:

```go
type Alert struct {
    Time         time.Time
    Rule         string
    Output       string
    Priority     string
    Source       string
    Hostname     string
    Tags         []string
    OutputFields map[string]interface{}
}

// Detection filtering
Detections() Detections                    // Parse alerts from stdout
OfPriority(p string) Detections            // Filter by priority
OfRule(v interface{}) Detections           // Filter by rule name (string or *regexp.Regexp)
Count() int                                // Number of alerts
```

**Source:** [`pkg/falco/tester_output_detection.go`](../../refs/falcosecurity/testing/pkg/falco/tester_output_detection.go)

### Rule Validation Output

For rules validation tests (`-V`):

```go
RuleValidation() *RuleValidationInfo       // Parse validation output
AllErrors() ValidationErrors               // Get all validation errors
OfCode(code string) ValidationErrors       // Filter by error code
OfItemType(t string) ValidationErrors      // Filter by item type
```

**Source:** [`pkg/falco/tester_output_validation.go`](../../refs/falcosecurity/testing/pkg/falco/tester_output_validation.go)

## Test Categories

### Legacy Tests

Ported from the original Python regression tests in falcosecurity/falco:
- `falco_tests.yaml`
- `falco_traces.yaml`
- `falco_tests_exceptions.yaml`

The porting was ~90% automated via a migration script.

**Source:** [`tests/falco/legacy_test.go:21-36`](../../refs/falcosecurity/testing/tests/falco/legacy_test.go)

### Test Data Generation

Test data files are generated via `go generate` from:
- Rules and configs from falcosecurity/falco source code (v0.34.1)
- Capture files from download.falco.org
- Inline string definitions

Data packages:
- `tests/data/rules/` - Rule files (legacy, falco, k8saudit, exceptions)
- `tests/data/configs/` - Configuration files
- `tests/data/captures/` - Capture files (.scap)
- `tests/data/outputs/` - Expected output files
- `tests/data/plugins/` - Plugin files

**Source:** [`tests/data/data.go`](../../refs/falcosecurity/testing/tests/data/data.go)

### Example Test

```go
func TestFalco_Legacy_Endswith(t *testing.T) {
    t.Parallel()
    checkConfig(t)
    res := falco.Test(
        tests.NewFalcoExecutableRunner(t),
        falco.WithOutputJSON(),
        falco.WithRules(rules.Endswith),
        falco.WithCaptureFile(captures.CatWrite),
        falco.WithArgs("-o", "json_include_output_property=false"),
        falco.WithArgs("-o", "json_include_tags_property=false"),
    )
    assert.NotZero(t, res.Detections().Count())
    assert.NotZero(t, res.Detections().OfPriority("WARNING").Count())
    assert.NoError(t, res.Err(), "%s", res.Stderr())
    assert.Equal(t, 0, res.ExitCode())
}
```

**Source:** [`tests/falco/legacy_test.go:84-99`](../../refs/falcosecurity/testing/tests/falco/legacy_test.go)

## CLI Usage

### Basic Usage

```bash
# Generate test files and binaries
go generate ./...

# Run all Falco tests
./build/falco.test

# Run with custom Falco binary
./build/falco.test -falco-binary /path/to/falco

# Run a specific test
./build/falco.test -test.run 'TestFalco_Legacy_WriteBinaryDir'

# Run falcoctl tests
./build/falcoctl.test

# Run k8saudit plugin tests
./build/k8saudit.test
```

**Source:** [`README.md`](../../refs/falcosecurity/testing/README.md)

### CLI Flags

| Flag | Description | Default |
|------|-------------|---------|
| `-falco-binary` | Path to Falco executable | `/usr/bin/falco` |
| `-falcoctl-binary` | Path to falcoctl executable | `/usr/local/bin/falcoctl` |
| `-falco-config` | Path to Falco config file | `/etc/falco/falco.yaml` |
| `-falco-container-plugin` | Path to container plugin `.so` | `/usr/share/falco/plugins/libcontainer.so` |
| `-falco-static` | True if using static Falco build | `false` |
| `-test.run` | Run only tests matching regexp | - |
| `-test.timeout` | Test timeout duration | - |
| `-test.v` | Verbose output | - |

**Source:** [`tests/tests.go:39-48`](../../refs/falcosecurity/testing/tests/tests.go)

## GitHub Action

A composite action for CI integration:

```yaml
- name: Run tests
  uses: falcosecurity/testing@main
  with:
    test-falco: 'true'      # Test Falco (default: true)
    test-falcoctl: 'false'  # Test falcoctl (default: false)
    test-k8saudit: 'false'  # Test k8saudit (default: false)
    test-dummy: 'false'     # Test dummy plugin (default: false)
    test-drivers: 'false'   # Test drivers, requires kernel headers (default: false)
    static: 'false'         # Static mode, only Falco tests (default: false)
    show-all: 'false'       # Show all tests in summary (default: false)
    sudo: 'sudo'            # Sudo command (default: 'sudo')
```

**Outputs:**
- `report`: Generated JUnit XML report path
- `out_file`: Full test output file path

**Note:** Since no annotated tags are used, reference by branch name or commit hash: `falcosecurity/testing@main` or `falcosecurity/testing@<commit-sha>`

**Source:** [`action.yml`](../../refs/falcosecurity/testing/action.yml)

## Falco CI Integration

The testing suite is used in Falco CI and must be kept in sync:

1. When Falco changes break tests, update tests in this repository
2. Open PR with necessary changes
3. After merge, bump submodule in falcosecurity/falco:
   ```bash
   cd submodules/falcosecurity-testing
   git fetch
   git merge origin/main
   ```
4. Include submodule update in the Falco PR

**Source:** [`README.md`](../../refs/falcosecurity/testing/README.md)

## Era 0.43 Changes

The latest commit (`2f1fba01`, February 5, 2026) removes all gRPC references; Falco 0.43.0 deprecated gRPC output and Falco 0.44.0 removed it entirely.

**Source:** Git commit message `2f1fba01`

## Key Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| `github.com/docker/docker` | v24.0.3 | Docker container execution |
| `github.com/stretchr/testify` | v1.8.1 | Test assertions |
| `github.com/sirupsen/logrus` | v1.9.0 | Logging |
| `gopkg.in/yaml.v3` | v3.0.1 | YAML parsing |
| `go.uber.org/multierr` | v1.9.0 | Error aggregation |

**Source:** [`go.mod`](../../refs/falcosecurity/testing/go.mod)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, usage, CI flow | [`README.md`](../../refs/falcosecurity/testing/README.md) |
| GitHub Action | [`action.yml`](../../refs/falcosecurity/testing/action.yml) |
| Runner interface | [`pkg/run/runner.go`](../../refs/falcosecurity/testing/pkg/run/runner.go) |
| Executable runner | [`pkg/run/executable.go`](../../refs/falcosecurity/testing/pkg/run/executable.go) |
| Falco test harness | [`pkg/falco/tester.go`](../../refs/falcosecurity/testing/pkg/falco/tester.go) |
| Falco test options | [`pkg/falco/tester_options.go`](../../refs/falcosecurity/testing/pkg/falco/tester_options.go) |
| Test output | [`pkg/falco/tester_output.go`](../../refs/falcosecurity/testing/pkg/falco/tester_output.go) |
| Detection assertions | [`pkg/falco/tester_output_detection.go`](../../refs/falcosecurity/testing/pkg/falco/tester_output_detection.go) |
| Test entry point, CLI flags | [`tests/tests.go`](../../refs/falcosecurity/testing/tests/tests.go) |
| Legacy tests | [`tests/falco/legacy_test.go`](../../refs/falcosecurity/testing/tests/falco/legacy_test.go) |
| Test data generation | [`tests/data/data.go`](../../refs/falcosecurity/testing/tests/data/data.go) |
| Dependencies | [`go.mod`](../../refs/falcosecurity/testing/go.mod) |
