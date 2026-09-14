# `prometheus` — kube-prometheus-stack + Grafana SSO

The monitoring stack, deployed into `monitoring` by `stacks/core`. Chart:
[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack),
**pinned to `90.1.1`** (`helm.tf`) — deliberately; see the note in `locals.tf`
and the Conventions section of the main README.

Everything below is a deliberate deviation from chart defaults. The comments in
`locals.tf` carry the reasoning; this is the summary.

## Grafana

- **Exposed at `grafana.<domain>`** on the shared private gateway (`listener.tf`
  → `gateway/expose`), cert from the private CA.
- **SSO-only UI:** `auth.disable_login_form = true`, with `auth.generic_oauth`
  pointed at authentik. Basic auth stays **enabled** on purpose — the chart's
  dashboard/datasource sidecars authenticate with it to call Grafana's
  provisioning-reload API, so turning it off kills hot-reload.
- **Role mapping:** members of `grafana-admin` (or of authentik's built-in
  `authentik Admins`, via `var.admin_group`) get Grafana Admin, everyone else
  Viewer. The JMESPath expression is parenthesised on purpose — `&&` binds
  tighter than `||`, and Grafana rejects a non-role.
- **The OIDC client lives in two stacks.** `stacks/mantle` (the authentik
  provider) creates the client and writes the credentials;
  `modules/monitoring/prometheus/grafana.tf` creates the Secret *object* with a
  placeholder so Grafana's `$__file{}` expander always finds a file (it hard-fails
  at startup when the mount is missing), and holds `ignore_changes = [data]` so
  the two stacks never flap. See [`../grafana_oidc/README.md`](../grafana_oidc/README.md).
- **`SSL_CERT_FILE`** points at the private CA cert, mirrored from the
  cluster-wide `linuxguru-ca` ConfigMap in `default` into this namespace
  (`grafana.tf`) — Grafana is Go, and it validates authentik's TLS cert.
- **`deploymentStrategy: Recreate`** because the Grafana PVC is Longhorn RWO: a
  RollingUpdate that lands the new pod on another node deadlocks on the volume.
- **`root_url` is explicit** — Grafana builds the OAuth `redirect_uri` from it,
  and authentik matches redirect URIs strictly.

## Prometheus

- `*SelectorNilUsesHelmValues = false`, so ServiceMonitors/PodMonitors in **any**
  namespace are discovered. That is what lets each component ship its own
  ServiceMonitor from its own module.
- **The control plane is deliberately not scraped** (`kubeEtcd`, `kubeScheduler`,
  `kubeControllerManager`, `kubeProxy` disabled) with the matching rule groups in
  `defaultRules.rules` also off. kubeadm binds those four metrics endpoints to
  loopback, so every target is a permanent connection-refused and the resulting
  alerts are pure noise — and because the `*Down` rules are `absent(up{...})`,
  removing the scrapers without removing the rules just trades one alert for
  another. Both levers move together. (etcd is the one exception worth turning
  on someday, via kubeadm extraArgs so it survives upgrades.)
- `crds.upgradeJob.enabled = true`: the chart's pre-install/pre-upgrade hook that
  server-side-applies the `.monitoring.coreos.com` CRDs. Helm never upgrades CRDs
  that live in a chart's `crds/` directory, which is how they drifted nine
  operator releases behind the operator serving them.

## Alerting

Alertmanager runs with the chart's **stock `null` receiver**: firing alerts are
visible in its UI and in Grafana, but nothing is delivered off-cluster. To wire a
destination, add an `alertmanager.config` block to `local.helm_values`. (An ntfy
integration was tried and removed 2026-09 — see `git log`.)

## Dashboards

Not owned here. Dashboards are ConfigMaps labelled `grafana_dashboard: "1"` that
each component ships from its own module and namespace; the chart's
`grafana-sc-dashboard` sidecar (live env `NAMESPACE=ALL`, `RESOURCE=both`) picks
them up cluster-wide. See the main README's Dashboards section.

## Variables

`namespace`, `domain`, `cert_issuer`, `prometheus_name` (`prometheus`),
`grafana_name` (`grafana`), `admin_group` (`authentik Admins`), `gateway_name`
(`private`), `gateway_namespace` (`kube-network`).
