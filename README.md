# Kubernetes Terraform

Everything in this repo is the cluster's own configuration: network, storage,
certs, identity, monitoring, the platform services, and the workloads on top of
them. The OS, kubeadm and Calico's data plane are not managed here.

State lives in Kubernetes Secrets in `kube-system` (one per stack), so there is
no remote backend to bootstrap and no state infrastructure to keep alive.

## Why three stacks

OpenTofu cannot configure a service in the same apply that creates it, when the
configuration needs a provider that does not exist until the service is up.
Harbor is the clean example: the chart is installed with the **helm** provider,
then its projects and OIDC are managed with the **harbor** provider — which
cannot even be configured until Harbor is serving. authentik and Argo CD are the
same shape (their providers need an API token minted from the release the same
apply just created). So this repo is three root modules, each with its own
state, applied in order.

## Layout

```
stacks/
├── core/     # platform: network, storage, certs, identity, monitoring, harbor, argo-cd, vpn
├── mantle/   # workloads + config owned by a provider core just created:
│             # media, blender, vaultwarden, seaweedfs-admin, whisker, grafana/harbor/argo SSO
└── apps/     # ArgoCD app-of-apps (the `ai` deployment; two wordpress deployments
              # are parked as *.tf.disabled)
```

State Secrets in `kube-system` are `tfstate-default-{core,mantle,deployment}`.

## Deployment order

1. **`stacks/core/`** — base infrastructure: Calico, MetalLB, the shared NGF
   gateways, external-dns, WireGuard, Longhorn, SeaweedFS, cert-manager,
   authentik, Prometheus/Grafana, Harbor, Argo CD, Gateway API CRDs.
2. **`stacks/mantle/`** — everything that needs a provider pointed at a service
   core just built: the media stack, blender, vaultwarden, the seaweedfs-admin
   and whisker authentik outposts, and the Grafana/Harbor/Argo CD SSO config.
3. **`stacks/apps/`** — ArgoCD `Application`s (app-of-apps) for `ai`.

**Order matters on a fresh cluster:** `core` installs the Gateway API CRDs, and
`mantle`'s HTTPRoutes are `kubernetes_manifest`s that need those CRDs to exist
at *plan* time.

## Running it

```sh
tofu -chdir=stacks/core   init && tofu -chdir=stacks/core   apply
tofu -chdir=stacks/mantle init && tofu -chdir=stacks/mantle apply
tofu -chdir=stacks/apps   init && tofu -chdir=stacks/apps   apply
```

- **Needs `kubectl` and a kubeconfig.** Every stack's providers point at
  `~/.kube/config`, and `modules/network/api_gateway_config.tf` shells out to
  `kubectl` to install the Gateway API CRDs.
- **Inputs** come from `stacks/<stack>/terraform.tfvars` (`deployment = {...}`,
  one bucket per concern: `domains`, `cert`, `cert_authorities`, `network`,
  `network_ingress`, `auth`, `vpn`, `media`, ...). tfvars is the single source of
  truth for the LAN CIDR, the cluster pod/service CIDRs and the MetalLB IPs that
  the firewall modules and gateways consume — renumbering the LAN is a one-line
  change there, not a code edit.
- **`tofu plan` is the drift check.** NetworkPolicies and most other resources
  are typed (`kubernetes_*`) rather than `kubectl_manifest` on purpose, so
  out-of-band edits show up as diffs instead of being silently ignored.

## What is exposed where

Only two ways in: the **public** gateway (`192.168.0.101`, WAN-forwarded) and
the **private** gateway (`192.168.0.100`, LAN + WireGuard only). Both drop
plain HTTP — HTTPS is the only way through them. The media apps sit on a third,
namespace-local gateway (`media-private`, `192.168.0.106`).

| Hostname | Gateway | Fronted by | Cert |
|---|---|---|---|
| `auth.vn.linuxguru.net` | private | — | `linuxguru-ca` |
| `argo-cd.vn.linuxguru.net` | private | authentik OIDC | `letsencrypt` |
| `argo-wf.vn.linuxguru.net` | private | authentik OIDC (Argo Workflows) | `linuxguru-ca` |
| `harbor.vn.linuxguru.net` | private | authentik OIDC | `linuxguru-ca` |
| `grafana.vn.linuxguru.net` | private | authentik OIDC | `linuxguru-ca` |
| `master.seaweedfs.vn.linuxguru.net`, `s3.vn.linuxguru.net` | private | — | `letsencrypt` |
| `admin.seaweedfs.vn.linuxguru.net` | private | authentik outpost (`storage`) | `letsencrypt` |
| `whisker.vn.linuxguru.net` | private | authentik outpost (`platform`) | `letsencrypt` |
| `ollama.vn.linuxguru.net` ⚠️ | private | **nothing** — unauthenticated, LAN/WireGuard only | `linuxguru-ca` |
| `vaultwarden.linuxguru.net` | private | — (clients are not browsers) | `letsencrypt` |
| `plex.linuxguru.net` | public | — | `letsencrypt` |
| `sonarr` / `radarr` / `prowlarr` / `bazarr` / `qbittorrent`.vn.linuxguru.net | media-private | authentik outpost (`media`) | `letsencrypt` |

⚠️ `ollama` is the `ai` namespace's model server: an HTTPRoute straight to the
Service, no authentik in front and no auth of its own. It is not published to
the internet (private gateway), but anything on the LAN or the VPN can use it.
Its exposure is created by the external app-of-apps repo, not by anything in this
repo — gutting it here would not remove it.

**Which cert a host gets** follows its clients, not its gateway. A host that only
browsers reach — or that nothing in-cluster talks to over TLS — is on
`letsencrypt` (public roots, no `~/.ssl/ca.crt` for the client). A host whose
*in-cluster* consumers look the CA up by issuer name stays on `linuxguru-ca`:
`auth.` itself, `harbor`, `grafana` and `argo-wf` (their Grafana/Workflows
containers mount the CA bundle), plus `ollama` (manifest owned elsewhere). The
whole list, the flip recipe and the rate limits live in
[`modules/cert_manager/README.md`](modules/cert_manager/README.md).

Non-HTTP ingress is separate: plex also listens on its own LoadBalancer, and
qBittorrent peers connect to `qbittorrent-torrent` on `192.168.0.105:21010` —
never through authentik.

## Module index

| Module | What it is |
|---|---|
| `network/` ([README](modules/network/README.md)) | Calico, MetalLB, external-dns (RFC2136 → bind9), the shared `public`/`private` NGF gateways, Gateway API CRD bootstrap, WireGuard |
| ↳ `network/firewalls/` ([README](modules/network/firewalls/README.md)) | NetworkPolicy library — `basic_internet` (egress), `limited_ingress` (ingress), `allow_api` (pod-scoped API egress) over one `policy` renderer |
| ↳ `network/gateway/` ([README](modules/network/gateway/README.md)) | one NGF control plane + `Gateway` per call; `expose` = `listener_set` + `http_route` in one call |
| ↳ `network/dns/route53_record/` ([README](modules/network/dns/route53_record/README.md)) | Terraform-authoritative Route53 record, for hosts external-dns cannot publish |
| ↳ `network/whisker/` ([README](modules/network/whisker/README.md)) | Calico Whisker flow-log UI, authentik-gated |
| `storage/` | Longhorn (+ netpols, `VolumeSnapshotClass`es), SeaweedFS (helm, CSI, master/S3 listeners, Grafana dashboard) |
| ↳ `storage/seaweedfs_admin/` ([README](modules/storage/seaweedfs_admin/README.md)) | SeaweedFS admin UI, authentik-gated (mantle) |
| `cert_manager/` ([README](modules/cert_manager/README.md)) | cert-manager (pinned `v1.21.1`), the private `linuxguru-ca` ClusterIssuer, the `letsencrypt` ClusterIssuer (Route53 DNS-01, zone pinned — `.vn` hosts included) |
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

Three shapes. Which one an app gets is decided by what its clients are — not by
preference:

| Pattern | Used by | Why that shape |
|---|---|---|
| **authentik proxy outpost** — the gateway routes the public hostname to an outpost, which authenticates then reverse-proxies to the app | sonarr/radarr/prowlarr/bazarr, the qbittorrent web UI, the SeaweedFS admin UI, whisker | the app speaks no OIDC, and its clients are browsers |
| **authentik OIDC** — the app is its own OIDC client and enforces its own groups/roles | Grafana, Harbor, Argo CD, Argo Workflows | the app speaks OIDC natively |
| **no auth in front** | `auth.` itself, SeaweedFS master/S3, plex, vaultwarden | the clients are not browsers (Bitwarden clients, the S3 API) or the service *is* the identity provider |

The cases that look wrong until you read why live in their own module docs:
[`media`](modules/media/README.md) (outpost wiring, the qbittorrent split, the
one-time per-app API config),
[`seaweedfs_admin`](modules/storage/seaweedfs_admin/README.md) (unauthenticated
`weed admin` behind SSO),
[`vaultwarden`](modules/vaultwarden/README.md) (public cert on a private
gateway, no outpost on purpose).

## Conventions

- **Version pinning.** Any Helm release you touch should pin its chart (and its
  image digest where the chart leaves the tag floating). Pinned today: MetalLB
  `0.16.1`, NGF `2.6.7`, kube-prometheus-stack `90.1.1`, Longhorn `1.12.1`,
  SeaweedFS `4.40.0` + CSI `0.2.35`, authentik `2025.10.3`, wireguard-operator
  `0.3.0`, cert-manager `v1.21.1`, and the media charts. **Still unpinned, so
  they float on any apply:** Harbor, external-dns, snapshot-controller,
  metrics-server, prometheus-smartctl-exporter, argo-cd and argo-events. This is
  not theoretical — kube-prometheus-stack rode four major versions unreviewed
  that way and left its CRDs nine operator releases behind the operator serving
  them. Pin on contact, and bump one version at a time.
- **Digest-pinned images with no version tag** (`flungo/avahi` in
  `modules/blender`) are deliberate: upstream publishes only `latest`/`main`, so
  a tag would be neither reproducible nor reviewable. Bump the digest by hand.
- **Terraform owns structure, the UI owns people.** Groups, applications and
  bindings are created here — `platform`, `media` and `storage` for the outpost
  apps, and `<app>-admin` / `<app>-user` for every OIDC client — but group
  *membership* is managed by hand in the authentik UI, so a from-scratch rebuild
  needs the members re-added (see `TODO.md`).
- **Secrets in tfvars, on purpose (and it is a compromise).**
  `terraform.tfvars` is in `.gitignore`, but `stacks/core` and `stacks/mantle`'s
  copies are tracked anyway — they carry the Route53 key, the bind9 TSIG secret
  and the Argo deploy key, and the stacks cannot plan without them. Treat those
  files as secrets; the AWS identity in them is deliberately least-privilege
  (one hosted zone). `stacks/apps` has no tfvars at all — create one before
  planning it.

## Alerting

`stacks/core` deploys the kube-prometheus-stack (Prometheus, Alertmanager,
Grafana) into `monitoring`. **Alertmanager has no receiver configured** — it runs
with the chart's stock `null` receiver, so firing alerts are visible in the
Alertmanager UI (and in Grafana) but nothing is delivered off-cluster. To wire up
a destination, add an `alertmanager.config` block to the helm values in
`modules/monitoring/prometheus/locals.tf`.

## Dashboards

Dashboards are ConfigMaps labelled `grafana_dashboard: "1"`, one `*.json` data
key each. The chart's `grafana-sc-dashboard` sidecar hot-loads them (its live env
is `NAMESPACE=ALL`, `RESOURCE=both`), so a dashboard may live in any namespace —
and to mirror the ServiceMonitors, **each component ships its own dashboard from
its own module and namespace** (`modules/storage/seaweedfs/dashboards.tf`)
rather than being pooled into the monitoring module. Grafana keys provisioned
dashboards off their `uid`, so editing a file updates it in place rather than
duplicating it.

## Gateway API (NGINX Gateway Fabric)

- `stacks/core` installs the **Gateway API CRDs** (`gateway.networking.k8s.io/*`)
  via a `terraform_data` bootstrap step in `modules/network/api_gateway_config.tf`
  (runs `kubectl`, idempotent, requires `kubectl` on the machine running tofu).
  The NGF Helm chart installs its own CRDs (`gateway.nginx.org/*`) automatically
  from its `crds/` directory — no manual step needed for those.
- **Rebuild order matters:** apply `stacks/core` before planning `stacks/mantle`,
  because the media module's HTTPRoutes (`kubernetes_manifest`) need the
  HTTPRoute CRD to exist at plan time.
- **The gateway module is generic shared infrastructure**
  ([`modules/network/gateway`](modules/network/gateway/README.md)): an NGF
  control plane + GatewayClass, plus a Gateway whose only built-in listener is
  `:80` HTTP — plain-HTTP requests are dropped (404), never redirected or served;
  HTTPS is the only way in, via app-declared `ListenerSet`s.
- **Shared `public` / `private` gateways** live in `kube-network`
  (`modules/network/gateways.tf`), watch all namespaces, allow ListenerSets from
  any namespace, and their data-plane Services are pinned to fixed MetalLB IPs
  (192.168.0.101 public / 192.168.0.100 private, wired via `gateway_ips` in
  `stacks/core` from tfvars `network_ingress.*_ip`) so DNS, NAT and firewall
  rules never have to move.
- **Each app owns its exposure** in its own module (`modules/<mod>/listener.tf`)
  via the [`gateway/expose`](modules/network/gateway/expose/README.md)
  submodule: one call renders the app's `ListenerSet` (its HTTPS listener on the
  public/private/media gateway) annotated with the cert-manager issuer so the
  `cert-<host>` secret is auto-provisioned (private CA or letsencrypt), plus an
  `HTTPRoute` (host -> service). Charts that render their own route
  (harbor/authentik/argo-cd) omit `backend_name` and get the listener only.
  Apps behind the authentik outpost (the arr apps, the qbittorrent web UI, the
  SeaweedFS admin UI, whisker) point the route at the outpost service instead
  (`route_name = "<app>-auth"`). `expose` auto-creates the cross-namespace
  `ReferenceGrant` when the gateway lives in another namespace. Certs and secrets
  live with the services that use them; rebuild-from-scratch is fully
  `tofu`-driven.

