# Kubernetes Terraform

The cluster's own configuration: network, storage, certs, identity, monitoring,
the platform services, and the workloads on top of them. The OS, kubeadm and
Calico's data plane are not managed here. State lives in Kubernetes Secrets in
`kube-system` (one per stack), so there is no remote backend to bootstrap.

## Three stacks, applied in order

OpenTofu cannot configure a service in the same apply that creates it when the
configuration needs a provider that does not exist until the service is up —
Harbor is the clean example (chart via **helm**, then projects/OIDC via the
**harbor** provider, which cannot even be configured until Harbor is serving).
authentik and Argo CD are the same shape: their providers need an API token
minted from the release the same apply just created.

| Stack | Owns | State Secret |
|---|---|---|
| `core` | Calico, MetalLB, the shared NGF gateways + Gateway API CRDs, external-dns, WireGuard, Longhorn, SeaweedFS, cert-manager, authentik, Prometheus/Grafana, Harbor, Argo CD | `tfstate-default-core` |
| `mantle` | everything needing a provider core just built: media, blender, vaultwarden, seaweedfs-admin, whisker, Grafana/Harbor/Argo SSO | `tfstate-default-mantle` |
| `apps` | ArgoCD app-of-apps (`ai`; a wordpress deployment is parked as `*.tf.disabled`) | `tfstate-default-deployment` |

**Order matters on a fresh cluster:** `core` installs the Gateway API CRDs and
`mantle`'s HTTPRoutes are `kubernetes_manifest`s that need them at *plan* time.

```sh
tofu -chdir=stacks/core   init && tofu -chdir=stacks/core   apply
tofu -chdir=stacks/mantle init && tofu -chdir=stacks/mantle apply
tofu -chdir=stacks/apps   init && tofu -chdir=stacks/apps   apply
```

- **Needs `kubectl` and `~/.kube/config`** — every provider points there, and
  `modules/network/api_gateway_config.tf` shells out to install the CRDs.
- **Inputs** are `stacks/<stack>/terraform.tfvars` (`deployment = {...}`, one
  bucket per concern), the single source of truth for the LAN/pod/service CIDRs
  and the MetalLB range, so renumbering is a tfvars edit. `stacks/apps` has no
  tfvars committed: pass `-var-file=~/.tfenvs/k8s.tfenv`, or create one holding
  `deployment = { common = { domain = "vn.linuxguru.net" } }`.
- **`tofu plan` is the drift check.** Resources are typed (`kubernetes_*`) rather
  than `kubectl_manifest` on purpose, so out-of-band edits show as diffs.
- **VIPs float; names are the interface.** Nothing pins a gateway or
  LoadBalancer address: each takes one from the MetalLB pool
  (`metal.networks`, `.100-.150`) and clients reach it by hostname — external-dns
  → bind9 for `.vn`, and vaultwarden's Route53 record reads the private
  gateway's live Service. An ordinary apply never moves an address (MetalLB
  keeps it for the life of the Service), but a *recreated* Service takes a new
  pool IP. The two addresses DNS cannot cover are router NAT rules — WAN 443 →
  public gateway, WAN 21010 → qbittorrent-torrent. Re-pinning:
  `modules/network/gateways.tf`.

## What is exposed where

Only two ways in: the **public** gateway (MetalLB VIP, `.101` today,
WAN-forwarded) and the **private** one (`.100`, LAN + WireGuard only). Both drop
plain HTTP, so HTTPS is the only way through. Media apps use a third,
namespace-local gateway (`media-private`, `.106`). All float like every other
LoadBalancer here; only the public one's WAN forward cares which address it
lands on. **Every host below serves a `letsencrypt` cert** (see "Which cert").

| Hostname | Gateway | Fronted by |
|---|---|---|
| `auth.vn.linuxguru.net` | private | — (it *is* the IdP) |
| `argo-cd.vn.linuxguru.net` | private | authentik OIDC |
| `argo-wf.vn.linuxguru.net` | private | authentik OIDC (Argo Workflows) |
| `harbor.vn.linuxguru.net` | private | authentik OIDC |
| `grafana.vn.linuxguru.net` | private | authentik OIDC |
| `master.seaweedfs.vn.linuxguru.net`, `s3.vn.linuxguru.net` | private | — (clients are not browsers) |
| `admin.seaweedfs.vn.linuxguru.net` | private | authentik outpost (`storage`) |
| `whisker.vn.linuxguru.net` | private | authentik outpost (`platform`) |
| `ollama.vn.linuxguru.net` ⚠️ | private | **nothing** — unauthenticated, LAN/WireGuard only |
| `corsless.vn.linuxguru.net` ⚠️ | private | **nothing** — CORS-bypass proxy, LAN/WireGuard only |
| `llm-embedder.vn.linuxguru.net` ⚠️ | private | **nothing** — unauthenticated, LAN/WireGuard only |
| `vaultwarden.linuxguru.net` | private | — (clients are not browsers) |
| `plex.linuxguru.net` | public | — |
| `sonarr` / `radarr` / `prowlarr` / `bazarr` / `qbittorrent`.vn.linuxguru.net | media-private | authentik outpost (`media`) |

⚠️ The three `ai` hosts are HTTPRoutes straight to their Services — no authentik,
no auth of their own, and `corsless` proxies any URL a client names. They exist
because of the external app-of-apps repo (`deployments/ai`), which declares each
ListenerSet + `ReferenceGrant` + HTTPRoute in its chart values (`extraObjects`);
gutting them here would not remove them. Nothing there is internet-facing
(private gateway), but the whole LAN and VPN can use it.

**Which cert a host gets** is `cert_authorities.default` in tfvars
(`letsencrypt`, DNS-01 via Route53) for every host since 2026-09-15: each either
serves only browsers or has in-cluster consumers that trust public roots
already. `~/.ssl/ca.crt` is needed by no client. The `linuxguru-ca`
ClusterIssuer still exists but is dormant (unreferenced; expires 2027-08-14) —
if you ever need it again, the per-consumer injection checklist (Argo CD first)
lives in
[`modules/cert_manager/README.md`](modules/cert_manager/README.md), with the
issuer table, the flip recipe and the rate limits.

Non-HTTP ingress is separate: plex also listens on its own LoadBalancer, and
qBittorrent peers connect to the `qbittorrent-torrent` VIP on `21010` (`.105`
today, and the router's WAN forward is why that address matters) — never through
authentik.

## Module index

| Module | What it is |
|---|---|
| `network/` ([README](modules/network/README.md)) | Calico, MetalLB, external-dns (RFC2136 → bind9), the shared `public`/`private` NGF gateways, Gateway API CRD bootstrap, WireGuard |
| ↳ `network/firewalls/` ([README](modules/network/firewalls/README.md)) | NetworkPolicy library — `basic_internet` (egress), `limited_ingress` (ingress), `allow_api` (pod-scoped API egress) over one `policy` renderer |
| ↳ `network/gateway/` ([README](modules/network/gateway/README.md)) | one NGF control plane + `Gateway` per call; `expose` = `listener_set` + `http_route` in one call |
| ↳ `network/dns/route53_record/` ([README](modules/network/dns/route53_record/README.md)) | Terraform-authoritative Route53 record, for hosts external-dns cannot publish |
| ↳ `network/whisker/` ([README](modules/network/whisker/README.md)) | Calico Whisker flow-log UI, authentik-gated |
| `storage/` ([README](modules/storage/README.md)) | Longhorn (+ netpols, `VolumeSnapshotClass`es, the cluster-wide recurring-snapshot jobs and their [recovery runbook](modules/storage/disaster_recovery.md)), SeaweedFS (helm, CSI, master/S3 listeners, Grafana dashboard) |
| ↳ `storage/seaweedfs_admin/` ([README](modules/storage/seaweedfs_admin/README.md)) | SeaweedFS admin UI, authentik-gated (mantle) |
| `cert_manager/` ([README](modules/cert_manager/README.md)) | cert-manager (pinned `v1.21.1`), the `letsencrypt` ClusterIssuer (Route53 DNS-01, zone pinned — `.vn` included) which signs **all 19 hosts**, and the dormant private `linuxguru-ca` |
| `auth/authentik/core/` | authentik server + worker + API key + listener |
| ↳ `auth/authentik/proxy_app/` ([README](modules/auth/authentik/proxy_app/README.md)) | authentik proxy provider/app/group **and** the outpost + its non-expiring token |
| ↳ `auth/authentik/outpost/` ([README](modules/auth/authentik/outpost/README.md)) | the outpost Deployment/Service in the protected app's namespace + its egress carve-out |
| ↳ `auth/authentik/oidc_provider/` | generic OIDC client for apps that speak OIDC (grafana, harbor, argo) |
| `monitoring/prometheus/` ([README](modules/monitoring/prometheus/README.md)) | kube-prometheus-stack (pinned), Grafana SSO, dashboards |
| `monitoring/grafana_oidc/` ([README](modules/monitoring/grafana_oidc/README.md)) | Grafana's authentik OIDC client + credentials (mantle) |
| `monitoring/metrics_server/`, `monitoring/smartctl/` | metrics-server; prometheus-smartctl-exporter for disk SMART |
| `harbor/core/`, `harbor/mantle/` | Harbor release + listener (core); projects + OIDC auth (mantle) |
| `argo/core/`, `argo/mantle/` | Argo CD release (core); its SSO/deploy key + argo-workflows + argo-events (mantle) |
| `argo/aoa_deployment/` | app-of-apps `Application` generator (apps stack) |
| `media/` ([README](modules/media/README.md)) | the `media` namespace: sonarr/radarr/prowlarr/bazarr/plex/qbittorrent, the `media-private` gateway, the authentik outpost, and the namespace netpols |
| `blender/` ([README](modules/blender/README.md)) | Samba share on the LAN + the mDNS advertiser macOS Finder needs |
| `vaultwarden/` ([README](modules/vaultwarden/README.md)) | Bitwarden-compatible server on the private gateway + its Route53 record |

## Access patterns

Three shapes, decided by what an app's clients are — not by preference:

| Pattern | Used by | Why that shape |
|---|---|---|
| **authentik proxy outpost** — the gateway routes the public hostname to an outpost, which authenticates then reverse-proxies | sonarr/radarr/prowlarr/bazarr, the qbittorrent web UI, the SeaweedFS admin UI, whisker | the app speaks no OIDC, and its clients are browsers |
| **authentik OIDC** — the app is its own OIDC client and enforces its own groups/roles | Grafana, Harbor, Argo CD, Argo Workflows | the app speaks OIDC natively |
| **no auth in front** | `auth.` itself, SeaweedFS master/S3, plex, vaultwarden | the clients are not browsers (Bitwarden clients, the S3 API) or the service *is* the IdP |

The cases that look wrong until you read why live in their own module docs:
[`media`](modules/media/README.md) (outpost wiring, the qbittorrent split, the
one-time per-app API config),
[`seaweedfs_admin`](modules/storage/seaweedfs_admin/README.md) (unauthenticated
`weed admin` behind SSO), [`vaultwarden`](modules/vaultwarden/README.md) (public
cert on a private gateway, no outpost on purpose).

## Conventions

- **Version pinning.** Every Helm chart and container image this repo deploys is
  pinned; nothing floats on a plain apply. Chart versions live in the owning
  module's `variables.tf` as a `helm_version` default (or `helm_<chart>_version`
  where a module ships several charts) — never as a literal in the
  `helm_release`, so `grep -rn helm_version modules` lists every pin. Provider
  versions are exact and per stack (`stacks/*/providers.tf`). Bump one at a time.

  Pinned today: cert-manager `v1.21.2`, MetalLB `0.16.1`, calico `v3.32.2`,
  external-dns `1.22.0`, NGF `2.7.1`, kube-prometheus-stack `91.4.1`, Longhorn
  `1.12.1`, SeaweedFS `4.40.0` + CSI `0.2.35`, snapshot-controller `5.2.0`,
  authentik `2026.8.2`, wireguard-operator `0.3.0`, Harbor `1.19.2`,
  metrics-server `3.14.0`, prometheus-smartctl-exporter `0.17.1`, argo-cd `10.9.1`,
  argo-workflows `2.0.6`, argo-events `2.4.27`, plex `1.9.0`, sonarr `2.2.3` /
  radarr `3.6.4` / prowlarr `3.8.4` / bazarr `2.3.1`. **Nothing floats on a plain
  apply any more** — the last unversioned releases were pinned 2026-09-16; what is
  left is the *version* gap, tracked per chart in `memory-bank/progress.md`. Why the
  rule exists: kube-prometheus-stack rode four major versions unreviewed that way
  and left its CRDs nine operator releases behind the operator serving them.
- **Image pins live with the image**, as a `*_image` / `image_tag` variable
  default (`modules/media/qbittorrent`, `modules/blender`,
  `modules/network/wireguard`). Version tag where upstream publishes one; digest
  only where it does not (`flungo/avahi` publishes just `latest`/`main`).
- **Every `helm_release` sets `wait = true` and `timeout = 600` explicitly.**
  `wait` is the provider default; `timeout` is not (300s), and a CRD-heavy chart
  can legitimately outlast it on a cold cluster.
- **Terraform owns structure, the UI owns people.** Groups, applications and
  bindings are created here — `platform`, `media` and `storage` for the outpost
  apps, `<app>-admin` / `<app>-user` for every OIDC client — but group
  *membership* is managed by hand in the authentik UI, so a from-scratch rebuild
  needs the members re-added (see `memory-bank/progress.md`).
- **Secrets in tfvars, on purpose (and it is a compromise).**
  `terraform.tfvars` is in `.gitignore`, but `stacks/core` and `stacks/mantle`'s
  copies are tracked anyway — they carry the Route53 key, the bind9 TSIG secret
  and the Argo deploy key, and the stacks cannot plan without them. Treat those
  files as secrets; the AWS identity in them is deliberately least-privilege
  (one hosted zone). `stacks/apps` has no tfvars at all — create one first.

## Backups and recovery

Longhorn snapshots are decided **per volume, cluster-wide**, in
[`modules/storage/longhorn_jobs.tf`](modules/storage/longhorn_jobs.tf): three
jobs (`snapshot-daily|weekly|monthly`, UTC, retain 2 each) joined to volumes by a
group label that only `modules/storage/snapshot_labeler.tf` writes. Eight PVCs
are enrolled, seven deliberately skipped, and **no job may ever list the
`default` group** — Longhorn puts every new unlabelled volume in it.

**These are recovery points, not backups**: no `backupTarget`, so no snapshot has
ever left the cluster, and they share the failure domain with their volume.
Coverage, the audit and the verified restore procedure (maintenance mode;
in-cluster-only manager API) are in
[`modules/storage/disaster_recovery.md`](modules/storage/disaster_recovery.md);
the offsite gap is tracked in `memory-bank/progress.md`.

## Alerting, dashboards, monitoring

- **Alertmanager has no receiver configured** — stock `null` receiver, so firing
  alerts are visible in its UI (and Grafana) but nothing is delivered
  off-cluster. To wire a destination, add an `alertmanager.config` block to the
  helm values in `modules/monitoring/prometheus/locals.tf`.
- **Dashboards are ConfigMaps** labelled `grafana_dashboard: "1"`, one `*.json`
  data key each. The chart's `grafana-sc-dashboard` sidecar hot-loads them (live
  env `NAMESPACE=ALL`, `RESOURCE=both`), so a dashboard may live in any
  namespace — and to mirror the ServiceMonitors, **each component ships its own
  from its own module and namespace**
  (`modules/storage/seaweedfs/dashboards.tf`) rather than being pooled into the
  monitoring module. Grafana keys provisioned dashboards off their `uid`, so
  editing a file updates in place rather than duplicating.

## Gateway API (NGINX Gateway Fabric)

- `stacks/core` installs **both CRD sets** — the Gateway API's
  (`gateway.networking.k8s.io/*`) and NGF's own (`gateway.nginx.org/*`) — via two
  `terraform_data` bootstraps in `modules/network/api_gateway_config.tf` (each runs
  `kubectl kustomize` at the NGF tag and re-runs only when its `triggers_replace`
  changes; both are idempotent and both need `kubectl` on the tofu box). NGF's CRDs
  are *also* vendored in the chart's `crds/`, but Helm applies that directory on
  **install only** — an upgrade never touches it, so the bootstrap is what actually
  keeps them current.
- **Rebuild order matters:** `core` before planning `mantle`, because the media
  module's HTTPRoutes (`kubernetes_manifest`) need the HTTPRoute CRD at *plan*
  time.
- **The gateway module is generic shared infrastructure**
  ([`modules/network/gateway`](modules/network/gateway/README.md)): an NGF
  control plane + GatewayClass, plus a Gateway whose only built-in listener is
  `:80` HTTP — plain-HTTP requests are dropped (404), never redirected or served;
  HTTPS is the only way in, via app-declared `ListenerSet`s.
- **Shared `public` / `private` gateways** live in `kube-network`
  (`modules/network/gateways.tf`), watch all namespaces, allow ListenerSets from
  any namespace, and their data-plane Services take a MetalLB VIP like every
  other LoadBalancer here — no `load_balancer_ip` is passed, so the address is
  never frozen in tfvars and DNS keeps up with it.
- **Each app owns its exposure** in its own module (`modules/<mod>/listener.tf`)
  via the [`gateway/expose`](modules/network/gateway/expose/README.md)
  submodule: one call renders the app's `ListenerSet` (its HTTPS listener on the
  public/private/media gateway) annotated with the cert-manager issuer so the
  `cert-<host>` secret is auto-provisioned (from `cert_authorities.default` —
  `letsencrypt` today), plus an `HTTPRoute` (host → service). Charts that render
  their own route (harbor/authentik/argo-cd) omit `backend_name` and get the
  listener only. Apps behind the authentik outpost (the arr apps, the qbittorrent
  web UI, the SeaweedFS admin UI, whisker) point the route at the outpost service
  instead (`route_name = "<app>-auth"`). `expose` auto-creates the
  cross-namespace `ReferenceGrant` when the gateway lives elsewhere. Certs and
  secrets live with the services that use them; rebuild-from-scratch is fully
  `tofu`-driven.




