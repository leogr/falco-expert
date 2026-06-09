# client-go Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/client-go/`](../../refs/falcosecurity/client-go/) | **Commit:** `5e214c6` (January 19, 2026)

**Repository:** [falcosecurity/client-go](https://github.com/falcosecurity/client-go)
**Scope:** Ecosystem
**Status:** Deprecated

---

## DEPRECATION NOTICE

**This project is DEPRECATED as of Falco 0.43.0 and the gRPC output was REMOVED in Falco 0.44.0.**

Starting from Falco version 0.43.0, the gRPC output API was deprecated, and Falco 0.44.0 removed it entirely. As a result, this client library has no upstream Falco server to connect to. This repository will be archived in the future.

**Deprecation discussion:** [falcosecurity/evolution#494](https://github.com/falcosecurity/evolution/issues/494)

**Do not use this library for new projects.** It is preserved here only for historical context and understanding of the legacy gRPC output architecture.

**Modern alternatives for consuming Falco alerts:**
- HTTP/HTTPS webhook output (`http_output`)
- File output with log aggregators
- Stdout/stderr with container log collection
- Direct integration via falcosidekick

**Source:** [`README.md`](../../refs/falcosecurity/client-go/README.md)

---

## Historical Overview

Go client library for Falco's (now deprecated) gRPC API. Provided programmatic access to:
- **Outputs API**: Stream Falco security alerts in real-time
- **Version API**: Query Falco server version

**Source:** [`README.md`](../../refs/falcosecurity/client-go/README.md)

## Architecture (Historical)

```
┌─────────────────┐                    ┌─────────────────┐
│  Go Application │                    │  Falco Daemon   │
│                 │                    │                 │
│  ┌───────────┐  │  gRPC (mTLS)       │  ┌───────────┐  │
│  │ client-go │◄─┼────────────────────┼──│ grpc_output│ │
│  └───────────┘  │  or Unix Socket    │  └───────────┘  │
└─────────────────┘                    └─────────────────┘
```

## Connection Types (Historical)

### mTLS Network Connection

Required mutual TLS authentication with client certificates:

```go
c, err := client.NewForConfig(context.Background(), &client.Config{
    Hostname:   "localhost",
    Port:       5060,
    CertFile:   "/etc/falco/certs/client.crt",
    KeyFile:    "/etc/falco/certs/client.key",
    CARootFile: "/etc/falco/certs/ca.crt",
})
```

### Unix Socket Connection

Simpler local connection without TLS:

```go
c, err := client.NewForConfig(context.Background(), &client.Config{
    UnixSocketPath: "unix:///run/falco/falco.sock",
})
```

**Source:** [`pkg/client/client.go`](../../refs/falcosecurity/client-go/pkg/client/client.go)

## Client Configuration (Historical)

```go
type Config struct {
    Hostname                  string           // Server hostname (network mode)
    Port                      uint16           // Server port (default 5060)
    CertFile                  string           // Client certificate path
    KeyFile                   string           // Client private key path
    CARootFile                string           // CA root certificate path
    UnixSocketPath            string           // Unix socket path (alternative to network)
    DialOptions               []grpc.DialOption // Additional gRPC dial options
    InsecureSkipMutualTLSAuth bool             // Skip mTLS verification (insecure)
}
```

**Source:** [`pkg/client/client.go:28-37`](../../refs/falcosecurity/client-go/pkg/client/client.go)

## Outputs API (Historical)

### Response Structure

The gRPC output response contained:

| Field | Type | Description |
|-------|------|-------------|
| `time` | `timestamp.Timestamp` | Event timestamp |
| `priority` | `Priority` | Alert priority (0=Emergency to 7=Debug) |
| `rule` | `string` | Name of the triggered rule |
| `output` | `string` | Formatted output message |
| `output_fields` | `map[string]string` | Extracted field values |
| `hostname` | `string` | Source hostname |
| `tags` | `[]string` | Rule tags |
| `source` | `string` | Event source (syscall, k8s_audit, etc.) |

**Source:** [`pkg/api/outputs/outputs.pb.go:83-98`](../../refs/falcosecurity/client-go/pkg/api/outputs/outputs.pb.go)

### Priority Levels

```go
Priority_EMERGENCY     = 0  // System is unusable
Priority_ALERT         = 1  // Action must be taken immediately
Priority_CRITICAL      = 2  // Critical conditions
Priority_ERROR         = 3  // Error conditions
Priority_WARNING       = 4  // Warning conditions
Priority_NOTICE        = 5  // Normal but significant
Priority_INFORMATIONAL = 6  // Informational messages
Priority_DEBUG         = 7  // Debug-level messages
```

**Source:** [`pkg/api/schema/schema.pb.go:38-65`](../../refs/falcosecurity/client-go/pkg/api/schema/schema.pb.go)

### Streaming Methods

- `Get()`: One-shot request, receive stream of outputs
- `Sub()`: Bidirectional streaming (send heartbeats, receive outputs)

```go
// Unidirectional streaming
fcs, err := outputsClient.Get(ctx, &outputs.Request{})

// Bidirectional streaming
fcs, err := outputsClient.Sub(ctx)
```

### Watch Helper

```go
// OutputsWatch provides a callback-based interface for consuming alerts
err := client.OutputsWatch(ctx, fcs, func(res *outputs.Response) error {
    fmt.Printf("Rule: %s, Priority: %s\n", res.Rule, res.Priority)
    return nil
}, 30*time.Second)  // timeout for heartbeats
```

**Source:** [`pkg/client/client.go:112-177`](../../refs/falcosecurity/client-go/pkg/client/client.go)

## Version API (Historical)

```go
versionClient, err := c.Version()
res, err := versionClient.Version(ctx, &version.Request{})
fmt.Printf("Falco version: %v\n", res)
```

**Source:** [`README.md`](../../refs/falcosecurity/client-go/README.md)

## Examples (Historical)

| Example | Description |
|---------|-------------|
| [`examples/output/`](../../refs/falcosecurity/client-go/examples/output/main.go) | Outputs over mTLS |
| [`examples/output_unix_socket/`](../../refs/falcosecurity/client-go/examples/output_unix_socket/main.go) | Outputs over Unix socket |
| [`examples/output_bidi/`](../../refs/falcosecurity/client-go/examples/output_bidi/main.go) | Bidirectional streaming over mTLS |
| [`examples/output_unix_socket_bidi/`](../../refs/falcosecurity/client-go/examples/output_unix_socket_bidi/main.go) | Bidirectional streaming over Unix socket |
| [`examples/version/`](../../refs/falcosecurity/client-go/examples/version/main.go) | Version query over mTLS |
| [`examples/version_unix_socket/`](../../refs/falcosecurity/client-go/examples/version_unix_socket/main.go) | Version query over Unix socket |

**Source:** [`README.md`](../../refs/falcosecurity/client-go/README.md)

## Dependencies (Historical)

| Dependency | Version | Purpose |
|------------|---------|---------|
| `google.golang.org/grpc` | 1.56.3 | gRPC framework |
| `google.golang.org/protobuf` | 1.33.0 | Protocol buffers |
| `github.com/gogo/protobuf` | 1.3.2 | JSON marshaling |

**Go version:** 1.17

**Source:** [`go.mod`](../../refs/falcosecurity/client-go/go.mod)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, deprecation notice | [`README.md`](../../refs/falcosecurity/client-go/README.md) |
| Client implementation | [`pkg/client/client.go`](../../refs/falcosecurity/client-go/pkg/client/client.go) |
| Outputs protobuf | [`pkg/api/outputs/outputs.pb.go`](../../refs/falcosecurity/client-go/pkg/api/outputs/outputs.pb.go) |
| Schema (priorities) | [`pkg/api/schema/schema.pb.go`](../../refs/falcosecurity/client-go/pkg/api/schema/schema.pb.go) |
| Dependencies | [`go.mod`](../../refs/falcosecurity/client-go/go.mod) |

## Related Documentation

- [Falco gRPC API (deprecated docs)](https://falco.org/docs/grpc/)
- [Deprecation discussion](https://github.com/falcosecurity/evolution/issues/494)
- [`falco/outputs.md`](falco/outputs.md) - Current output channels
- [`falcoctl.md`](falcoctl.md) - Modern CLI tool
