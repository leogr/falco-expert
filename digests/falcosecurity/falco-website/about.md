# Falco About and Marketing Content Digest

Era: 0.44

## What is Falco

[Source: _index.md](../../../refs/falcosecurity/falco-website/content/en/about/_index.md)

Falco is a real-time threat detection solution for containers, hosts, Kubernetes, and the cloud. Originally developed as open source by Sysdig, Falco was contributed to the Cloud Native Computing Foundation (CNCF) in 2018, moved to incubating level in 2020, and graduated in 2024. It has been downloaded more than 100 million times.

### Core Concept

Falco works like a network of security cameras for infrastructure:
- Deploy Falco across distributed infrastructure
- Falco collects data from local machines or APIs
- Runs a set of rules against the data
- Notifies when suspicious behavior is detected

### Data Sources

Falco collects event data from multiple sources:
- Linux kernel syscalls (primary source)
- Kubernetes audit logs
- Cloud events (e.g., AWS CloudTrail)
- Events from other systems (GitHub, Okta)
- Custom data sources via plugins

### Kernel Instrumentation

Falco instruments the Linux kernel using:
- **eBPF probe** (default): Revolutionary technology for running sandboxed programs in the OS kernel, flexible, safe, and fast
- **Kernel module**: Traditional approach for extending Linux kernel functionality, efficient for performance-critical work

### Threat Detection Capabilities

Falco detects and alerts on abnormal behavior including:
- Crypto mining
- File exfiltration
- Privilege escalation
- Rootkit installations
- Unauthorized workload deployment
- Unauthorized access to secrets
- Malware activation

## Why Falco

[Source: why-falco.md](../../../refs/falcosecurity/falco-website/content/en/about/why-falco.md)

### Highly Scalable

- Containerized architecture with tight Kubernetes integration
- Runs as a Kubernetes DaemonSet ensuring every node is monitored
- Leverages Kubernetes API to dynamically update configuration
- Integrates with Prometheus and Grafana for alert visualization at scale

### Highly Performant

- Low overhead, event-driven architecture
- Uses minimal resources (CPU, memory, I/O)
- Monitors only relevant events, reducing noise and latency
- Kernel-level instrumentation observes system events non-intrusively

### Single Policy Language

- Reduces complexity and misconfigurations
- Promotes collaboration between Security and Ops teams
- Flexible and extensible for custom rules
- Simplifies compliance and auditing

### Flexible Deployment Options

- Deploy on hosts, VMs, or Kubernetes (on-prem or cloud)
- Born cloud-native, works as containerized app in K8s clusters
- Integrates with cloud-native services (Prometheus, Grafana)
- Uses eBPF by default for simplified deployment

### Customizable

- Define custom rules for specific security requirements
- Build custom plugins for additional event sources
- Configure alerts to trigger custom actions
- Enrich alerts with custom metadata

## Use Cases

[Source: use-cases.md](../../../refs/falcosecurity/falco-website/content/en/about/use-cases.md)

### MITRE ATT&CK Framework Alignment

[Source: mitre.md](../../../refs/falcosecurity/falco-website/content/en/about/mitre.md)

Falco's threat detection capabilities align with the MITRE ATT&CK framework:
- Detects Tactics, Techniques, and Procedures (TTPs) employed by adversaries
- Aids rapid identification and response to security incidents
- Helps organizations proactively defend systems

### Regulatory Compliance

Falco supports compliance with frameworks including:
- **PCI DSS**: Detects unauthorized file changes and access attempts
- **NIST**: Real-time runtime detection for cloud-native systems

Falco detects compliance violations including:
- Unauthorized access attempts
- Privilege escalation
- Data exfiltration attempts

### Monitoring Scope

Falco monitors:
- **Workloads**: Processes, containers, services
- **Infrastructure**: Hosts, VMs, network, cloud infrastructure and services

## Ecosystem

[Source: ecosystem.md](../../../refs/falcosecurity/falco-website/content/en/about/ecosystem.md)

### Falcosidekick

Companion application that forwards Falco events to 50+ destinations:
- Email
- Chat (Slack, Teams, etc.)
- Message queues
- Serverless functions
- Databases
- Cloud services

### Plugins

Extend Falco capabilities with plugins:
- Add new event streams as inputs
- Enrich events with contextual information
- Build custom plugins using the plugin-sdk-go

### Helm Charts

Official Helm charts available for Kubernetes deployment at https://github.com/falcosecurity/charts

## Case Studies

[Source: case-studies/_index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/_index.md)

### R6 Security (Phoenix Platform)

[Source: case-studies/r6-security/index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/r6-security/index.md)

**Company**: R6 Security, founded 2020

**Product**: Phoenix - Moving Target Defense (MTD) security solution for Kubernetes

**Falco Integration**:
- Falco serves as the underlying detection mechanism
- When Falco detects suspicious activity, Phoenix's automated remediation kicks off
- Example: Shell exec into container detected by Falco triggers Phoenix operator to tag and deactivate the compromised container

**Results**:
- 80-85% attack detection rate (based on red teaming)
- 1-8% additional CPU/memory overhead
- Real-time alerting enables immediate cluster configuration adjustments

**Key reasons for choosing Falco**:
- Powerful threat detection capabilities
- Strength of the Falco community
- Proven track record with other users

### Incepto Medical

[Source: case-studies/incepto-medical/index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/incepto-medical/index.md)

**Company**: Incepto Medical - AI-powered medical imaging analysis

**Use Case**: Multi-tenant medical imaging service with strict privacy/security requirements

**Infrastructure**:
- AWS Kubernetes clusters on GPU-enabled Ubuntu instances
- Tenant segmentation via namespace and Cilium CNI
- Self-managed EC2 instances with Terraform/KOPS

**Falco Integration**:
- Deployed as DaemonSet monitoring syscalls and K8s audit logs
- Falcosidekick forwards alerts to Slack, segmented by client namespace
- Custom rules for S3 bucket monitoring (data exfiltration/corruption detection)

**Key Benefits**:
- Detects drift in production workloads
- Monitors partner-submitted custom container images
- Ensures tenant isolation security

### Trendyol

[Source: case-studies/trendyol/index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/trendyol/index.md)

**Company**: Trendyol - Leading Turkish e-commerce platform (30M+ customers, 4000+ employees)

**Scale**: Multiple production Kubernetes clusters across 9 regions, 700,000+ K8s audit logs per minute

**Architecture**:
- Falco + Fluent Bit monitoring system
- Fluent Bit collects logs, Falco detects Indicators of Compromise (IoC)
- File-based log forwarding for scalability

**Detection Focus**:
- Unauthorized privilege escalation
- Unauthorized Kubernetes secrets access
- Interactive access to production containers

**Results**:
- Repeatable configuration pattern across all clusters
- Optimized resource utilization
- Comprehensive threat detection and long-term log storage

## Frequently Asked Questions

[Source: faq.md](../../../refs/falcosecurity/falco-website/content/en/about/faq.md)

### What is runtime security?

Runtime security provides real-time monitoring capabilities for hosts, containers, and applications while running. It detects:
- Privilege escalation attacks
- Unauthorized workload deployment
- Unauthorized access to secrets
- Malware activation

Falco alerts instantly when detecting unwanted behavior.

### How does Falco work in a nutshell?

Falco is like smart security cameras for infrastructure: sensors observe activity and alert on harmful behavior defined by rules. Alerts can stay local or export to a centralized collector.

### Can Falco run in VMs?

Yes, Falco runs on almost any Linux kernel - bare-metal servers, VMs, or microVMs. Prebuilt drivers available at https://download.falco.org/driver/site/index.html

### Does Falco need to run in every container/pod?

No. Falco deploys once per Linux OS (typically as privileged DaemonSet). It instruments the Linux kernel and monitors everything on the node since containers share the same kernel. Falco associates kernel events with container/Kubernetes attributes (container ID, name, namespace, pod name).

### Why does Falco need a driver?

System calls are Falco's default data source. To instrument the Linux kernel, Falco needs either a Linux kernel module or eBPF probe.

### Which Linux kernels are compatible?

The Falco Project provides thousands of prebuilt drivers for major Linux distributions. For kernels >= 5.8, modern_bpf driver uses BTF/eBPF CORE and works without kernel headers across all distros.

### Can I build the kernel driver for custom kernels?

Yes:
- **Kernel module/old eBPF**: Need extracted kernel headers
- **Modern eBPF** (kernels >= 5.8): No kernel headers needed (uses BTF/eBPF CORE)

### How to reduce excessive notifications?

- Disable/customize noisy default rules
- Use tags for rule filtering
- Override default macros
- Configure minimum rule priority threshold
- Use rate limiter (may reduce threat visibility)

### Falco not triggering alerts - what's wrong?

1. Verify Falco is running
2. Event must occur on same host as Falco
3. Check rule conditions aren't too strict
4. Note: Falco uses buffers, alerts may take seconds to appear

### Does Falco cover all system calls?

Falco supports specific system call event types (see documentation). By default, only a subset is considered for performance. Use `base_syscalls.all: true` config option to consider all events. Proper rules are still needed to detect threats.

> Note: The `-A` CLI flag was removed in 0.41; use the config option instead.

### Do I need -k flag for Kubernetes metadata?

No. Fields like `k8s.ns.name`, `k8s.pod.name`, `k8s.pod.id`, `k8s.pod.labels` are populated from container runtime without the Kubernetes Metadata Enrichment (-k) option.

### What is Falco's performance overhead?

Performance overhead varies with server load and workload type. Factors include:

- **CPU**: Scales with syscall volume; network-heavy servers use more CPU
- **Memory**: Ring buffer per CPU; process state builds over time

**Tuning options**:
- Perform cost-benefit analysis on activated syscalls
- Conduct performance tests early
- Run Falco in cgroups
- Adjust ring buffer sizes for high-load servers

## Source Files

- [_index.md](../../../refs/falcosecurity/falco-website/content/en/about/_index.md) - Main "What is Falco" page
- [why-falco.md](../../../refs/falcosecurity/falco-website/content/en/about/why-falco.md) - Benefits and features
- [use-cases.md](../../../refs/falcosecurity/falco-website/content/en/about/use-cases.md) - Use cases and compliance
- [ecosystem.md](../../../refs/falcosecurity/falco-website/content/en/about/ecosystem.md) - Ecosystem integrations
- [faq.md](../../../refs/falcosecurity/falco-website/content/en/about/faq.md) - FAQ page structure
- [mitre.md](../../../refs/falcosecurity/falco-website/content/en/about/mitre.md) - MITRE ATT&CK page (placeholder)
- [case-studies/_index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/_index.md) - Case studies index
- [case-studies/r6-security/index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/r6-security/index.md) - R6 Security case study
- [case-studies/incepto-medical/index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/incepto-medical/index.md) - Incepto Medical case study
- [case-studies/trendyol/index.md](../../../refs/falcosecurity/falco-website/content/en/about/case-studies/trendyol/index.md) - Trendyol case study
