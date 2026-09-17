# Network

Cluster-wide network infrastructure, applied from `stacks/core` (with one
exception: the `whisker/` submodule is instantiated by `stacks/mantle`, which is
the stack holding the authentik provider). Everything in this directory either
*is* the shared network layer or is a reusable building block consumed by other
modules.

## What it deploys

| Component | Detail |
|---|---|
| **Calico** | CNI + NetworkPolicy enforcement (`calico.tf`, `tigera-operator` chart) |
| **MetalLB** | L2 LoadBalancer pool for the LAN (`metallb.tf`, addresses from `metal_networks`) |
| **external-dns** | Publishes Services/HTTPRoutes to the internal Bind zone via RFC2136 (`external_dns.tf`, chart values in `charts.tf`). Authoritative for `vn.linuxguru.net` only — hence `dns/route53_record` for everything else |
| **NGF gateways** | `public` and `private` NGINX Gateway Fabric control planes + data planes in `kube-network` (`gateways.tf` + `gateway/`). VIPs come from the MetalLB pool — nothing is pinned — and external-dns publishes the assigned IP into bind9, so reach them by name |
| **CRDs** | one-time bootstrap of `gateway.networking.k8s.io/*` **and** NGF's own `gateway.nginx.org/*` (`api_gateway_config.tf`) — the chart's `crds/` is install-only, so this bootstrap is what upgrades them |

Most apps do *not* live here. `kube-network` is the shared **platform** namespace:
the gateway data planes that front every namespace's HTTPS routes, external-dns,
MetalLB, and the Calico operator. Workload modules (media, auth, harbor, argo,
...) expose themselves by instantiating the `gateway/expose` submodule from their
own namespaces.

## Submodules

| Path | What it is |
|---|---|
| [`gateway/`](gateway/README.md) | One NGINX Gateway Fabric instance per Gateway (control plane + Gateway resource) |
| [`gateway/expose/`](gateway/expose/README.md) | One call to publish an app: HTTPS ListenerSet (+ cert/grants) and optional HTTPRoute |
| [`gateway/listener_set/`](gateway/listener_set/README.md) | App-owned HTTPS listener on a Gateway + auto cert + ReferenceGrants (used by `expose`) |
| [`gateway/http_route/`](gateway/http_route/README.md) | App-owned hostname → Service route with external-dns annotation (used by `expose`) |
| [`firewalls/`](firewalls/README.md) | `NetworkPolicy` builders, one call = one object: **`egress`** per pod profile, **`egress_peer`** for one namespace + pod + port, **`ingress`** for the inbound direction |
| [`firewalls/egress/`](firewalls/egress/README.md) | **Egress**: DNS always, own-namespace by default, plus namespace / API-server / cluster / internet / raw-CIDR peers. Call sites: `media` (4), `kube-storage` (4), `argo` (4), `harbor` (3), `cert_manager` (2), `seaweedfs_admin` (1), `blender` (1), `vaultwarden` (1) |
| [`firewalls/ingress/`](firewalls/ingress/README.md) | **Ingress**: own namespace and the node addresses always, every other guest named explicitly, with its own ports. Call site so far: `kube-storage` (1) |
| [`wireguard/`](wireguard/README.md) | VPN operator + peers (own namespace `kube-network-vpn`) |
| [`whisker/`](whisker/README.md) | Calico Whisker flow-log UI: authentik outpost + listener + the tier CRs the operator's own policy forces — instantiated by `stacks/mantle`, because it needs the authentik provider |
| [`dns/route53_record/`](dns/route53_record/README.md) | Terraform-authoritative Route53 record, for hosts external-dns cannot publish |

## NetworkPolicy: egress first, ingress only where the guests have been measured

`firewalls/egress/` renders every **egress** policy this repo owns — one call, one pod selector,
`Egress` only. Call sites so far:

| Where | Policies | Profile |
|---|---|---|
| [`../media/egress.tf`](../media/egress.tf) | 4 | One namespace-wide call (`podSelector: {}`) = own namespace + DNS + the public internet, plus three pod-scoped exceptions: the NGF control plane and its cert-generator hook pod get the API server, the outpost gets one pod in `kube-auth` on one port. |
| [`../storage/egress.tf`](../storage/egress.tf) | 4 | The **closed floor** used namespace-wide (28 pods): own namespace + DNS, no internet, no LAN, no other namespace. Plus the API server for `seaweedfs-csi-controller`, `seaweedfs-csi-node` (registrar) and `snapshot-controller`. |
| [`../storage/seaweedfs_admin/egress.tf`](../storage/seaweedfs_admin/egress.tf) | 1 | The co-located outpost's single peer: authentik's server pod in `kube-auth`, :9000. |
| [`../harbor/core/egress.tf`](../harbor/core/egress.tf) | 3 | DNS + own namespace for all seven chart pods, `+ allow_internet` for `component=trivy`, `+` the private gateway peer for `component=core`. |
| [`../blender/egress.tf`](../blender/egress.tf) | 1 | DNS + own namespace. The share initiates nothing. |
| [`../vaultwarden/egress.tf`](../vaultwarden/egress.tf) | 1 | Same two-rule shape, selected by the Deployment's labels. |

Every other namespace still reaches every other namespace, the internet, and the API.
Anything that reads like a policy rationale for those is history kept for the migration.

The **ingress** direction is one namespace deep: [`../storage/ingress.tf`](../storage/ingress.tf)
governs all of `kube-storage` — its own pods, the node addresses, the private gateway's data plane on
the three backend ports that namespace's HTTPRoutes name, and Prometheus on `:9327` (2026-09-17). So
nothing else restricts inbound, which is why a LAN client can still reach Plex or SMB after a
namespace is "locked down" — and why the S3 consumers of `kube-storage` that live outside this repo
are covered anyway: every Service in there is ClusterIP, so the gateway pod is the only door they can
come through, and a pod selector names that door exactly.

One exception is not ours: the tigera-operator (v3.32.2+) enforces its own tier
`calico-system` (`defaultAction: Deny`), so pods in `calico-system` are dropped
both ways regardless of what this repo does. `whisker/tier.tf` carries three Calico
CRs in that tier purely to let whisker and its SSO outpost function — delete them
and the UI breaks again. Details: [`whisker/README.md`](whisker/README.md) and
`.clinedocs/calico-netpols.md`.
