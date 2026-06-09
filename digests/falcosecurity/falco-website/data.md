# Falco Website Data Digest

> AI-optimized digest of structured data from falcosecurity/falco-website
> Era: Falco 0.44

---

## Key Statistics

**Source:** [facts.yaml](../../../refs/falcosecurity/falco-website/data/en/facts.yaml)

- 175M+ Container image pulls
- 50+ Integrations
- 8,600+ GitHub stars
- 1,600+ contributors

---

## Features

**Source:** [features.yaml](../../../refs/falcosecurity/falco-website/data/en/features.yaml)

### Cloud Native
Falco detects threats across containers, Kubernetes, hosts and cloud services.
- Uses eBPF to monitor system activity for adverse behavior
- Integrated with Kubernetes
- Use plugins to monitor cloud services such as GitHub, Okta, or AWS Cloudtrail

### Real Time Detection
Falco provides streaming detection of unexpected behavior, configuration changes, and attacks.
- Runtime detection is a fundamental layer of defense against security blind spots and zero-day bugs in your software supply chain
- Streaming approach enables real-time response while minimizing storage costs and complexity
- Ready out-of-the-box with rules, which you can customize for your environment

### Integration with 50+ Systems
Forward Falco alerts to any off-host SIEM and data lake system for analysis, storage, or reaction.
- Falco alerts can easily be forwarded to more than 50+ third parties
- The JSON format for alerts allows for storing, analysis, or triggering reactions easily

### Open Source
A multi-vendor and widely adopted solution that you can rely on.
- Created cloud native in the same community as Kubernetes, Prometheus, and OPA
- Powered by eBPF technology
- Runs on x64 & ARM CPUs
- Deployable in Kubernetes with an official Helm chart
- Run on many platforms like GKE, EKS, AKS and others
- Zero cost to start, and easy to audit, extend, and integrate

---

## Use Cases

**Source:** [usecases.yaml](../../../refs/falcosecurity/falco-website/data/en/usecases.yaml)

### Threat Detection
Detect malicious behavior in hosts and containers, no matter what scale, using the power of eBPF.

### Regulatory Compliance
Stay compliant in cloud-native systems with Falco's intelligent monitoring and rule-based detection.

---

## Adopters

**Source:** [boozallen.yaml](../../../refs/falcosecurity/falco-website/data/adopters/endusers/boozallen.yaml) (and other files in adopters/)

### End Users

**Source:** [boozallen.yaml](../../../refs/falcosecurity/falco-website/data/adopters/endusers/boozallen.yaml)

| Organization | Website |
|-------------|---------|
| Booz Allen Hamilton | https://www.boozallen.com/ |
| Control Plane | https://controlplane.com/ |
| Frame.io | https://frame.io/ |
| GitLab | https://about.gitlab.com/ |
| KubeSphere | https://kubesphere.io |
| League | https://league.com/us/ |
| NETWAYS Web Services | https://nws.netways.de/en |
| Preferral | https://www.preferral.com/ |
| Shopify | https://shopify.com |
| Sight Machine | https://sightmachine.com/ |
| Skyscanner | https://medium.com/@SkyscannerEng/kubernetes-security-monitoring-at-scale-with-sysdig-falco-a60cfdb0f67a |
| stack.io | https://stack.io/ |
| Vinted | https://www.vinted.com |

### Vendors

**Source:** [hpe.yaml](../../../refs/falcosecurity/falco-website/data/adopters/vendors/hpe.yaml)

| Organization | Website |
|-------------|---------|
| Hewlett Packard Enterprise | https://docs.ezmeral.hpe.com/runtime-enterprise/56/reference/kubernetes/kubernetes-administrator/clusters/cluster-add-ons/Falco_Container_Security.html |
| KubeSphere | https://kubesphere.io |
| Logz.io | https://logz.io/ |
| Rancher | https://rancher.com |
| Shujinko | https://www.shujinko.io/products/ |
| Sumo Logic | https://www.sumologic.com/ |
| Sysdig | https://sysdig.com |

### Integrations

**Source:** [aws.yaml](../../../refs/falcosecurity/falco-website/data/adopters/integrations/aws.yaml)

| Integration | Website |
|------------|---------|
| Amazon Web Services | https://aws.amazon.com/ |
| Azure | https://azure.microsoft.com |
| Datadog | https://www.datadoghq.com/ |
| Elasticsearch | https://www.elastic.co/elasticsearch |
| Google Cloud | https://cloud.google.com/ |
| gVisor | https://gvisor.dev/ |
| Helm | https://helm.sh |
| IBM Cloud | https://www.ibm.com/cloud |
| InfluxDB | https://www.influxdata.com/ |
| Kubernetes | https://kubernetes.io |
| Grafana Loki | https://grafana.com/oss/loki/ |
| Open Policy Agent | https://www.openpolicyagent.org/ |
| Opsgenie | https://www.atlassian.com/software/opsgenie |
| Prometheus | https://prometheus.io/ |
| Red Hat | https://www.redhat.com |
| Slack | https://slack.com/ |
| StatsD | https://github.com/statsd/statsd |

### Plugins

**Source:** [aws-cloudtrail.yaml](../../../refs/falcosecurity/falco-website/data/adopters/plugins/aws-cloudtrail.yaml)

| Plugin | Description | Repository |
|--------|-------------|------------|
| AWS CloudTrail | Reads CloudTrail JSON logs from files/S3 and injects as events | https://github.com/falcosecurity/plugins/tree/master/plugins/cloudtrail |
| AWS EKS | Read Kubernetes Audit Events from AWS EKS Clusters | https://github.com/falcosecurity/plugins/tree/master/plugins/k8saudit-eks |
| Docker | Read Docker events | https://github.com/Issif/docker-plugin |
| GitHub | Collect GitHub Webhook Events | https://github.com/falcosecurity/plugins/tree/master/plugins/github |
| Kubernetes | Collect Kubernetes Audit Events and monitor Kubernetes Clusters | https://github.com/falcosecurity/plugins/tree/master/plugins/k8saudit |
| Nomad | Collect Nomad events | https://github.com/albertollamaso/nomad-plugin/tree/main |
| Okta | Collect Okta Audit logs | https://github.com/falcosecurity/plugins/tree/master/plugins/okta |

---

## Training Resources

**Source:** [types.yaml](../../../refs/falcosecurity/falco-website/data/training/types.yaml)

### Training Types

**Source:** [types.yaml](../../../refs/falcosecurity/falco-website/data/training/types.yaml)

- Course
- Lab
- Book

### Training Providers

**Source:** [linux-foundation.yaml](../../../refs/falcosecurity/falco-website/data/training/providers/linux-foundation.yaml)

#### Linux Foundation Training and Certification
https://training.linuxfoundation.org/

#### Sysdig
https://www.sysdig.com

### Available Courses

**Source:** [lsf254.yaml](../../../refs/falcosecurity/falco-website/data/training/offerings/lsf254.yaml)

| Course | Provider | Duration | Description |
|--------|----------|----------|-------------|
| Detecting Cloud Runtime Threats with Falco (LFS254) | Linux Foundation | 20 hours | Learn about Falco and how to install and use it in securing cloud native environments |
| Falco 101 | Sysdig | 5 hr 41 min | All you need to learn to get started with Falco |
| Falco Plugins | Sysdig | 1 hr 27 min | Extending Falco to secure your cloud services |
| Detecting a Cryptomining Malware attack with Falco and Prometheus | Sysdig | 2 hr 00 min | Learn how to detect Cryptominers with Falco and Prometheus |

---

## Community Channels

**Source:** [community.yaml](../../../refs/falcosecurity/falco-website/data/en/community.yaml)

| Platform | Link |
|----------|------|
| Slack | https://kubernetes.slack.com/messages/falco |
| GitHub | https://github.com/falcosecurity/falco |
| YouTube | https://www.youtube.com/@falcosecurity |
| Docker Hub | https://hub.docker.com/u/falcosecurity |

---

## CLI Options (Quick Reference)

**Source:** [cli_options.yaml](../../../refs/falcosecurity/falco-website/data/en/reference/daemon/cli_options.yaml)

| Flag | Description | Default |
|------|-------------|---------|
| `-c` | Configuration file | `/etc/falco/falco.yaml` |
| `-d` / `--daemon` | Run as a daemon | - |
| `-D <pattern>` | Disable any rules matching the regex pattern (cannot be used with `-t`) | - |
| `-e <events_file>` | Read events from file (`.scap` for sinsp events, `jsonl` for K8s audit) | - |
| `-k` / `--k8s-api <url>` | Enable Kubernetes support by connecting to API server | - |

> Note: CLI flags `-A`, `-b`, `-S/--snaplen` were removed in 0.41. Use config options instead (`base_syscalls.all`, `falco_libs.snaplen`).

---

## Configuration Options Reference

**Source:** [config_options.yaml](../../../refs/falcosecurity/falco-website/data/en/reference/daemon/config_options.yaml)

### Core Configuration

| Option | Type | Description |
|--------|------|-------------|
| `rules_files` | List | Location of the rules file(s). Can contain one or more paths. |
| `plugins` | List of objects | Defines the set of plugins Falco can load. Sub-keys: `name`, `library_path`, `init_config`, `open_params` |
| `load_plugins` | List | Plugin names to actually load (optional - if not present, all plugins are loaded) |
| `watch_config_files` | Boolean | Watch config and rules files for modification and hot reload (default: true) |
| `time_format_iso_8601` | Boolean | Display times in ISO 8601 format (default: false) |
| `priority` | Enum | Minimum rule priority level to load/run |

### Output Configuration

| Option | Type | Description |
|--------|------|-------------|
| `json_output` | Boolean | Print alerts and validation results as JSON (default: false) |
| `json_include_output_property` | Boolean | Include `output` property in JSON output (default: true) |
| `json_include_tags_property` | Boolean | Include `tags` property in JSON output (default: true) |
| `buffered_outputs` | Boolean | Buffer output to output channels (default: false) |

### Logging

| Option | Type | Description |
|--------|------|-------------|
| `log_stderr` | Boolean | Log Falco activity to stderr |
| `log_syslog` | Boolean | Log Falco activity to syslog |
| `log_level` | Enum | Minimum log level (`emergency`, `alert`, `critical`, `error`, `warning`, `notice`, `info`, `debug`) |
| `libs_logger` | List | Configure libs logging (sub-keys: `enabled`, `severity`) |

### Output Channels

| Option | Type | Description |
|--------|------|-------------|
| `syslog_output` | Object | Send alerts via syslog (`enabled`) |
| `file_output` | Object | Send alerts to file (`enabled`, `keep_alive`, `filename`) |
| `stdout_output` | Object | Send alerts to stdout (`enabled`) |
| `program_output` | Object | Send alerts to a program (`enabled`, `keep_alive`) |
| `http_output` | Object | Send alerts to HTTP endpoint (`enabled`, `url`) |
| `grpc_output` | Object | Enable gRPC output collection (`enabled`) |

### Event Handling

| Option | Type | Description |
|--------|------|-------------|
| `syscall_event_drops` | Object | Configure actions for dropped syscall events. Actions: `ignore`, `log`, `alert`, `exit` |
| `syscall_event_timeouts` | Object | Configure max consecutive timeouts (`max_consecutives`, default: 1000) |
| `output_timeout` | Integer | Milliseconds to wait before considering outputs blocked (default: 2000ms) |

### Web Server & gRPC

| Option | Type | Description |
|--------|------|-------------|
| `webserver` | Object | Embedded web server config (`enabled`, `listen_port`, `k8s_audit_endpoint`, `ssl_enabled`, `ssl_certificate`, `threadiness`) |
| `grpc` | Object | gRPC server config (`enabled`, `bind_address`, `threadiness`, `private_key`, `cert_chain`, `root_certs`) |

---

## Supported Syscalls

**Source:** [cheatsheet.yaml](../../../refs/falcosecurity/falco-website/data/cheatsheet.yaml)

### Event Categories

| Category | Description |
|----------|-------------|
| `EC_PLUGIN` | Plugin events (`pluginevent`) |
| `EC_SYSCALL` | System call events |
| `EC_TRACEPOINT` | Kernel tracepoint events (`page_fault`, `procexit`, `signaldeliver`, `switch`) |
| `EC_INTERNAL` | Internal events (`container`, `drop`, `infra`, `k8s`, `mesos`, `procinfo`, `scapevent`) |

### Key Syscalls Monitored (Partial List)

Process-related:
- `clone`, `clone3`, `fork`, `vfork`, `execve`, `execveat`

File operations:
- `open`, `openat`, `openat2`, `creat`, `close`, `read`, `write`, `readv`, `writev`
- `chmod`, `chown`, `fchmod`, `fchown`, `link`, `unlink`, `rename`, `mkdir`, `rmdir`

Network:
- `socket`, `connect`, `bind`, `listen`, `accept`, `accept4`
- `send`, `sendto`, `recv`, `recvfrom`, `sendmsg`, `recvmsg`

Security-sensitive:
- `ptrace`, `bpf`, `setuid`, `setgid`, `chroot`, `mount`, `umount`
- `capset`, `prctl`, `seccomp`, `setns`, `unshare`

---

## Canonical Tags (Documentation Categories)

**Source:** [architecture.yaml](../../../refs/falcosecurity/falco-website/data/canonical-tags/architecture.yaml)

| ID | Name | Description |
|----|------|-------------|
| `architecture` | Architecture | The inner components of Falco |
| `community` | Community | Related to Falco open source development |
| `event-source` | Event Source | Source of events for Falco |
| `extension` | Extension | Supported customizations of Falco |
| `fundamental` | Fundamental | Relevant for a first-time user of Falco |
| `integration` | Integration | Terms related to Falco integration capabilities to consume logs and send alerts |
| `security-concept` | Security Concept | Useful security concepts to understand how Falco works |
| `tool` | Tool | Software that makes Falco easier or better to use |

---

## Blog Tags

**Source:** [blog_tags.yaml](../../../refs/falcosecurity/falco-website/data/en/blog_tags.yaml)

- Falco
- Falcosidekick
- Integration
- Falcosidekick-UI
- Falcoctl
- Falco Libs
- eBPF
- Kmod
- Rules
- Falco Plugins
- Release
- Tutorial
- News
- Community
- Live Event
- Use Case
- User Story
- Kubernetes
- Cloud
- Configuration Management

---

## Video Resources

**Source:** [videos.yaml](../../../refs/falcosecurity/falco-website/data/videos.yaml)

### Featured Playlists
- Pinned playlist: `PLgVVUpW8NIJDaH2_KOVPvDsQQ-4he2wxX`
- Featured playlist: `PLgVVUpW8NIJAaa6AZmVWIGo34s7Gmndid`
- Community playlist: `PLgVVUpW8NIJB7tPnjqbR4rySh9pg7XSbr`

### Introduction Video
- **Title**: What is Falco?
- **Description**: Learn how Falco detects and responds to suspicious container activities, understand its key features, and discover how to integrate it into your containerized environments.
- **Video ID**: `so5_iIA9wZM`
- **Published**: 2022-03-22

---

## Frequently Asked Questions

**Source:** [faq.yaml](../../../refs/falcosecurity/falco-website/data/en/faq.yaml)

### What is runtime security?
Runtime security is the process of providing real-time monitoring or observability capabilities for your host, containers, and applications while they're running. Falco detects:
- Privilege escalation attacks
- Unauthorized workload deployment
- Unauthorized access to secrets
- Activation of hidden malware

### How does Falco work (simple explanation)?
Falco is like smart security cameras for your infrastructure: sensors are placed in key locations, they observe what's going on, and they alert you if they detect harmful behavior. Rules define what bad behavior is, and alerts can be exported to a centralized collector.

### Can Falco run in VMs?
Yes, Falco can run in almost every Linux kernel, whether bare-metal server, VM, or microVM.

### Does Falco need to run in every container/pod?
No, Falco is deployed once per Linux OS (typically as a privileged DaemonSet in Kubernetes). It instruments the Linux kernel and can monitor everything within each container on the same node.

### Why does Falco need a driver?
System calls are Falco's default data source. To instrument the Linux kernel and collect these system calls, it needs a driver: either a Linux kernel module or an eBPF probe.

### Which Linux kernels are compatible?
The Falco Project provides thousands of prebuilt drivers for most common Linux distributions. For newer kernels >= 5.8, Falco supports the `modern_bpf` eBPF driver which uses BTF information and eBPF CORE (no kernel headers needed).

### How do I reduce excessive notifications?
- Disable or customize noisy rules
- Override default macros
- Configure minimum rule priority
- Use rate limiting (note: may reduce threat visibility)

### What is the performance overhead?
Performance overhead varies based on server load and workload footprint. Options to tune:
- Analyze syscalls based on your threat model
- Conduct performance tests early
- Run Falco in cgroups
- Memory scales with CPUs (ring buffer per CPU)

### Do I need -k flag for Kubernetes metadata?
No, the `k8s.ns.name` and `k8s.pod.*` fields are populated from the container runtime and can be accessed without the -k flag.

---

## Case Studies / Quotes

**Source:** [quotes.yaml](../../../refs/falcosecurity/falco-website/data/en/quotes.yaml)

### R6 Security (Phoenix)
> "Falco's threat detection and real-time alerting capabilities, together with Phoenix's mitigation features help effectively address security issues that might evade other security offerings"
> - Zsolt Nemeth, CEO at R6 Security Inc

### Trendyol
> "At Trendyol, we leverage Falco to develop a threat detection system using Kubernetes audit logs and kernel events to monitor user behavior in production clusters. This lets us detect operational anti-patterns, enhance visibility, and identify malicious actors."
> - Furkan Tural & Emin Aktas, Platform Engineers at Trendyol

### Incepto Medical
> "Incepto Medical uses Falco to provide a secure on-demand medical imaging service to healthcare facilities. Their platform enables partners to run custom applications (workloads) in a multi-tenant environment while protecting sensitive customer data thanks to Falco."
> - Alexandre Lemaresquier, Head of SecDevOps at Incepto Medical

---

## Speaker Resources

**Source:** [slideTemplates.yaml](../../../refs/falcosecurity/falco-website/data/en/slideTemplates.yaml)

### Presentation Templates
| Resource | Description |
|----------|-------------|
| [Empty Falco slide template](https://docs.google.com/presentation/d/1j7r-YTbCB5qL8MTzLTPDvSHIF6xO5STNBLTIf_UqDjQ/edit?usp=sharing) | 11 slides |
| [Turnkey, scripted Falco slides](https://docs.google.com/presentation/d/14GoUgYHE8dR1sELb7VWdyIWqw0FwTWW-rM9X-C2KQb4/edit#slide=id.g22d6f266885_0_0) | 11 slides |
| [Example video on Falco basics](https://www.youtube.com/watch?v=MTgfstE0U7E&t=3s) | 1 video |
| [Diagrams (SVG and PNG)](https://github.com/falcosecurity/falco-website/tree/master/static/img) | 10 diagrams |

---

## Notable Contributors (Monthly Awards)

**Source:** [contributors.yaml](../../../refs/falcosecurity/falco-website/data/contributors.yaml)

| Period | Contributors |
|--------|--------------|
| March 2023 | Federico Di Pierro |
| February 2023 | Melissa Kilby, David Windsor |
| January 2023 | Logan Bond |
| January/February 2022 | Alban Crequy |
| November/December 2021 | Pablo Lopez Zaldivar |
| September/October 2021 | Leo Di Donato |
| August 2021 | Teryl Taylor, Frederico Araujo |
| July 2021 | Furkan Turkal |
| June 2021 | Ismail Yenigul |
| May 2021 | Batuhan Apaydin, Yuvraj |
| April 2021 | Batuhan Apaydin, Yuvraj |
| March 2021 | Frank Jogeleit |
| February 2021 | Scott Nichols |
| January 2021 | Carlos Panato, KeisukeYamashita, Rajakavitha Kodhandapani |
| December 2020 | Massimiliano Giovagnoli, Jonah Jones |
| November 2020 | Thomas Labarussias |

---

## Source Files Reference

All data in this digest is extracted from YAML files in the falcosecurity/falco-website repository.

| Section | Source Path |
|---------|-------------|
| Key Statistics | [facts.yaml](../../../refs/falcosecurity/falco-website/data/en/facts.yaml) |
| Features | [features.yaml](../../../refs/falcosecurity/falco-website/data/en/features.yaml) |
| Use Cases | [usecases.yaml](../../../refs/falcosecurity/falco-website/data/en/usecases.yaml) |
| Adopters (End Users) | [boozallen.yaml](../../../refs/falcosecurity/falco-website/data/adopters/endusers/boozallen.yaml) |
| Adopters (Vendors) | [hpe.yaml](../../../refs/falcosecurity/falco-website/data/adopters/vendors/hpe.yaml) |
| Adopters (Integrations) | [aws.yaml](../../../refs/falcosecurity/falco-website/data/adopters/integrations/aws.yaml) |
| Adopters (Plugins) | [aws-cloudtrail.yaml](../../../refs/falcosecurity/falco-website/data/adopters/plugins/aws-cloudtrail.yaml) |
| Training Types | [types.yaml](../../../refs/falcosecurity/falco-website/data/training/types.yaml) |
| Training Providers | [linux-foundation.yaml](../../../refs/falcosecurity/falco-website/data/training/providers/linux-foundation.yaml) |
| Training Offerings | [lsf254.yaml](../../../refs/falcosecurity/falco-website/data/training/offerings/lsf254.yaml) |
| Community Channels | [community.yaml](../../../refs/falcosecurity/falco-website/data/en/community.yaml) |
| CLI Options | [cli_options.yaml](../../../refs/falcosecurity/falco-website/data/en/reference/daemon/cli_options.yaml) |
| Configuration Options | [config_options.yaml](../../../refs/falcosecurity/falco-website/data/en/reference/daemon/config_options.yaml) |
| Syscalls/Cheatsheet | [cheatsheet.yaml](../../../refs/falcosecurity/falco-website/data/cheatsheet.yaml) |
| Canonical Tags | [architecture.yaml](../../../refs/falcosecurity/falco-website/data/canonical-tags/architecture.yaml) |
| Blog Tags | [blog_tags.yaml](../../../refs/falcosecurity/falco-website/data/en/blog_tags.yaml) |
| Videos | [videos.yaml](../../../refs/falcosecurity/falco-website/data/videos.yaml) |
| FAQ | [faq.yaml](../../../refs/falcosecurity/falco-website/data/en/faq.yaml) |
| Quotes/Case Studies | [quotes.yaml](../../../refs/falcosecurity/falco-website/data/en/quotes.yaml) |
| Speaker Resources | [slideTemplates.yaml](../../../refs/falcosecurity/falco-website/data/en/slideTemplates.yaml) |
| Contributors | [contributors.yaml](../../../refs/falcosecurity/falco-website/data/contributors.yaml) |
