# falcosidekick-ui Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falcosidekick-ui/`](../../refs/falcosecurity/falcosidekick-ui/) | **Commit:** `2fc51f2` (May 19, 2026)

**Repository:** [falcosecurity/falcosidekick-ui](https://github.com/falcosecurity/falcosidekick-ui)
**Scope:** Ecosystem
**Status:** Incubating

Web UI for displaying and exploring Falco events stored by Falcosidekick.

---

## NOTICE: Limited Curation

**This project has limited maintenance and may contain bugs.**

- Recent commits are primarily automated dependency bumps
- Status is **Incubating** (not yet stable)
- May have UI/UX issues or incomplete features
- Use with appropriate expectations for a community-maintained UI project

**Recommended for:** Development, testing, demos, or environments where some instability is acceptable.

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

---

## Overview

A Vue.js-based web application that provides:
- Dashboard view of Falco events
- Event filtering by priority, rule, source, tags
- Event search with pagination
- Time-based filtering
- Event counts and statistics

**Requires:** Redis with [RediSearch](https://github.com/RediSearch/RediSearch) module (v2+)

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Falco       │────▶│  Falcosidekick  │────▶│     Redis       │
│                 │     │                 │     │  (RediSearch)   │
└─────────────────┘     └────────┬────────┘     └────────┬────────┘
                                 │                       │
                                 │ webui output          │ read events
                                 ▼                       │
                        ┌─────────────────┐              │
                        │ Falcosidekick   │◀─────────────┘
                        │      UI         │
                        │  (Port 2802)    │
                        └─────────────────┘
```

**Integration:** Configure Falcosidekick with `webui` output pointing to Falcosidekick-UI.

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Installation

### Docker

```bash
docker run -d -p 2802:2802 \
  -e FALCOSIDEKICK_UI_REDIS_URL=redis:6379 \
  falcosecurity/falcosidekick-ui
```

### With Docker Compose (full stack)

```yaml
services:
  redis:
    image: redislabs/redisearch:2.2.4
    ports:
      - "6379:6379"

  falcosidekick-ui:
    image: falcosecurity/falcosidekick-ui
    ports:
      - "2802:2802"
    environment:
      - FALCOSIDEKICK_UI_REDIS_URL=redis:6379
    depends_on:
      - redis

  falcosidekick:
    image: falcosecurity/falcosidekick
    environment:
      - WEBUI_URL=http://falcosidekick-ui:2802
    depends_on:
      - falcosidekick-ui
```

### Helm

Deploy via falcosidekick Helm chart with UI enabled:

```bash
helm install falcosidekick falcosecurity/falcosidekick \
  --set webui.enabled=true \
  --set webui.redis.enabled=true
```

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Configuration

| Flag | Environment Variable | Default | Description |
|------|---------------------|---------|-------------|
| `-a` | `FALCOSIDEKICK_UI_ADDR` | `0.0.0.0` | Listen address |
| `-p` | `FALCOSIDEKICK_UI_PORT` | `2802` | Listen port |
| `-r` | `FALCOSIDEKICK_UI_REDIS_URL` | `localhost:6379` | Redis server address |
| `-y` | `FALCOSIDEKICK_UI_REDIS_USERNAME` | (empty) | Redis username |
| `-w` | `FALCOSIDEKICK_UI_REDIS_PASSWORD` | (empty) | Redis password |
| `-t` | `FALCOSIDEKICK_UI_TTL` | `0` | Event TTL (format: `Xs`, `Xm`, `Xh`, `Xd`, `XW`, `XM`, `Xy`) |
| `-u` | `FALCOSIDEKICK_UI_USER` | `admin:admin` | User credentials (`login:password`) |
| `-d` | `FALCOSIDEKICK_UI_DISABLEAUTH` | `false` | Disable authentication |
| `-l` | `FALCOSIDEKICK_UI_LOGLEVEL` | `info` | Log level (debug, info, warning, error) |
| `-x` | `FALCOSIDEKICK_UI_DEV` | `false` | Enable CORS for development |

**Precedence:** Flag value → Environment variable → Default value

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md), [`main.go`](../../refs/falcosecurity/falcosidekick-ui/main.go)

## API Endpoints

Base URL: `http://localhost:2802/api/v1/`

| Route | Method | Description |
|-------|--------|-------------|
| `/` | `POST` | Add event (used by Falcosidekick) |
| `/healthz` | `GET` | Health check |
| `/authenticate`, `/auth` | `POST` | Authenticate user |
| `/configuration`, `/config` | `GET` | Get configuration |
| `/outputs` | `GET` | Get Falcosidekick outputs list |
| `/event/count` | `GET` | Count all events |
| `/event/count/priority` | `GET` | Count events by priority |
| `/event/count/rule` | `GET` | Count events by rule |
| `/event/count/source` | `GET` | Count events by source |
| `/event/count/tags` | `GET` | Count events by tags |
| `/event/search` | `GET` | Search events |

### Query Parameters

| Parameter | Description |
|-----------|-------------|
| `pretty` | Return formatted JSON |
| `priority` | Filter by priority |
| `rule` | Filter by rule name |
| `filter` | Filter by term |
| `source` | Filter by source |
| `tags` | Filter by tags |
| `since` | Time filter (second, min, day, week, month, year) |
| `limit` | Limit results (default: 100) |
| `page` | Pagination page number |

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## UI Endpoints

| Route | Description |
|-------|-------------|
| `/` | Main web UI |
| `/docs` | Swagger API documentation |

**Default URL:** `http://localhost:2802/`

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Falcosidekick Configuration

To send events to Falcosidekick-UI, configure the `webui` output in Falcosidekick:

```yaml
webui:
  url: "http://falcosidekick-ui:2802"
```

Or via environment variable:

```bash
WEBUI_URL=http://falcosidekick-ui:2802
```

See [`falcosidekick/outputs.md`](falcosidekick/outputs.md) for full output configuration.

**Source:** Falcosidekick documentation

## Technical Stack

| Component | Technology |
|-----------|------------|
| Backend | Go (Echo framework) |
| Frontend | Vue.js |
| Database | Redis + RediSearch |
| API Docs | Swagger |
| Build | Make, yarn |

**Requirements for development:**
- Go >= 1.18
- Node.js >= v14
- yarn >= 1.22

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Authentication

Default credentials: `admin:admin`

To change:
```bash
-u myuser:mypassword
# or
FALCOSIDEKICK_UI_USER=myuser:mypassword
```

To disable authentication:
```bash
-d true
# or
FALCOSIDEKICK_UI_DISABLEAUTH=true
```

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Event TTL

Configure how long events are retained in Redis:

```bash
# Keep events for 7 days
-t 7d
# or
FALCOSIDEKICK_UI_TTL=7d
```

Format: `X<unit>` where unit is:
- `s` - seconds
- `m` - minutes
- `h` - hours
- `d` - days
- `W` - weeks
- `M` - months
- `y` - years

`0` = no expiration (default)

**Source:** [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, usage | [`README.md`](../../refs/falcosecurity/falcosidekick-ui/README.md) |
| Main application | [`main.go`](../../refs/falcosecurity/falcosidekick-ui/main.go) |
| Configuration | [`configuration/configuration.go`](../../refs/falcosecurity/falcosidekick-ui/configuration/configuration.go) |
| Frontend | [`frontend/`](../../refs/falcosecurity/falcosidekick-ui/frontend/) |

## Related Documentation

- [`falcosidekick/README.md`](falcosidekick/README.md) - Falcosidekick overview
- [`falcosidekick/outputs.md`](falcosidekick/outputs.md) - WebUI output configuration
- [`charts.md`](charts.md) - Helm chart (includes falcosidekick-ui option)
