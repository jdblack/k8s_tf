# `smartctl` — disk SMART metrics

Deploys the
[prometheus-smartctl-exporter](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-smartctl-exporter/values.yaml)
chart (OCI, `ghcr.io/prometheus-community/charts`) into `monitoring`, with
`serviceMonitor.enabled = true` so the `prometheus` module's Prometheus scrapes
it. Chart **version is unpinned today** — pin it when you touch the module.

The exporter reads SMART data off the nodes' disks, so it needs host device
access; check the chart's `daemonset`/privilege settings if it ever stops
reporting rather than assuming the metrics vanished upstream.

Consumed by nothing in-repo yet: there are no SMART alerts or dashboard panels
committed. A first dashboard would follow the pattern in the main README
(a `grafana_dashboard: "1"` ConfigMap shipped from this module's namespace).

Variables: `name` (`smartctl`), `namespace`.
