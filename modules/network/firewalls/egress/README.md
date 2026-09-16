# egress

One call renders exactly one `NetworkPolicy`, `policyTypes: ["Egress"]`. Callers state intent;
the module decides selectors, CIDRs and rule order. Fourteen policies are live across
`modules/media`, `modules/harbor`, `modules/storage`, `modules/blender` and `modules/vaultwarden`; a
peer that needs a pod selector *and* a port is the one thing this module cannot say — that is
[`../egress_peer`](../egress_peer/README.md). [`../README.md`](../README.md) carries the wiring
state, including the two shapes a namespace-wide call can take (a closed floor, or the namespace
profile), and the worked examples are below.

```hcl
# Real caller shape: the NGF cert-generator Job, which only ever dials the API.
module "egress_for_gateway_hook" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "gateway-hook-egress"
  pod_selector  = { "job-name" = "ngf-nginx-gateway-fabric-cert-generator" }
  allow_k8s_api = true
}
```

Renders four rules, in this order:

```
1. pods in kube-network, no ports                      (self)
2. pods in kube-system, k8s-app=kube-dns, UDP+TCP/53   (always)
3. TCP/443  -> 10.96.0.1/32                            (the Service ClusterIP)
4. TCP/6443 -> the control-plane addresses             (192.168.0.74 today)
```

Rules 3 and 4 are the API pair, and which one *matches* is a property of the dataplane rather than
a choice: kube-proxy DNATs a ClusterIP dial to an endpoint before the policy chain runs, so on
this cluster (iptables) that flow reads `<node-ip>:6443` and **rule 4 is the one that grants API
access**. Measured, one scratch policy per port: ClusterIP/443 alone permits nothing, the node
address on 6443 alone permits the ClusterIP dial. Rule 3 is what a dataplane matching pre-DNAT
would need — inert here, never widening, and not safe to drop.

## Variables

| Variable | Type | Default | Means |
|---|---|---|---|
| `namespace` | `string` | — | Namespace whose pods this governs, and where the policy lives |
| `pod_selector` | `map(string)` | `{}` | Governed pods; `{}` = every pod in the namespace |
| `name` | `string` | `null` | `metadata.name`; wins outright over `name_prefix` |
| `name_prefix` | `string` | `null` | Generated name, `<prefix>-<8 hex>`. Default prefix is `namespace-egress` |
| `allow_namespace` | `bool` | `true` | This namespace's own pods — the self rule. Peers elsewhere are `to_namespaces` |
| `to_namespaces` | `list(string)` | `[]` | Whole-namespace peers, by name, no pod selector. A name given twice collapses to one rule |
| `allow_k8s_api` | `bool` | `false` | The API server, as two rules: `TCP/6443` to the control-plane addresses (the one that matches here) and `TCP/443` to the Service ClusterIP |
| `allow_cluster` | `bool` | `false` | The pod CIDR and the service CIDR, wholesale. Rare — prefer `to_namespaces` |
| `allow_internet` | `bool` | `false` | `0.0.0.0/0` except RFC1918 + link-local. Never reaches the LAN |
| `to_cidrs` | `list(string)` | `[]` | Extra CIDRs, one `ipBlock` peer each (a NAS, an off-cluster host, the LAN). Duplicates collapse |

`allow_*` are the switches; `to_*` take explicit peer lists. One call = one object, so a namespace
that needs two very different policies gets two calls, scoped with `pod_selector`, rather than one
wide one.

## Always on

**DNS.** `UDP+TCP/53` to `kube-system` / `k8s-app=kube-dns`, no knob: a pod-scoped policy that
silently loses DNS looks exactly like a broken application. Only the pod's own queries are covered —
kube-dns's upstream lookups are kube-dns's traffic, not the caller's.

**Self.** Every pod in `var.namespace`, rendered first, on by default: intra-namespace traffic is
implicit in nearly every app, so the burden sits with the caller who genuinely wants a namespace
walled off from itself (`allow_namespace = false`).

Neither is needed for *replies*: an established flow is not re-evaluated against policy, so a server
never needs a rule for the clients it answers. Rules are for connections the pod **initiates**.

## Typical profiles

### Namespace profile — every pod, this namespace + DNS + the internet

```hcl
module "egress_media" {
  source = "../network/firewalls/egress"

  namespace      = "media"   # no pod_selector: podSelector {} = every pod, present and future
  name           = "media-baseline-egress"
  allow_internet = true      # plex.tv, indexers, torrent trackers and peers
}
```

```
1. ns media, no ports                                  (self)
2. ns kube-system: k8s-app=kube-dns, UDP+TCP/53
3. ipBlock 0.0.0.0/0 except 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16
```

No API and no cluster. The LAN is deliberately absent too: LAN clients come *in* through the
namespace's gateway, and those replies ride the established flow. `allow_internet` excludes RFC1918,
so LAN reach is never a side effect of it — a media server that wants Plex discovery on the LAN has
to ask for the CIDR.

This is `media`'s actual shape since 2026-09-17: the namespace-wide call *is* the namespace's policy,
and the only other calls there carry exceptions — the API server for the gateway and its
cert-generator hook pod, one peer into `kube-auth` for the outpost. Dropping `allow_internet` and the
name renders the same three rules minus the third, which is the **closed floor**: same contract, but
it grants nothing beyond DNS + self, for namespaces where each pod still speaks for itself.

### File server — one CIDR, no internet

```hcl
module "egress_samba" {
  source = "../network/firewalls/egress"

  namespace   = "blender"
  name_prefix = "blender-egress"
  to_cidrs    = ["192.168.0.20/32"]   # the NAS it backs up to
}
```

```
1. ns blender, no ports                   (self)
2. ns kube-system: k8s-app=kube-dns, UDP+TCP/53
3. ipBlock 192.168.0.20/32
```

The inbound side — SMB on 445, the mDNS advertisement — needs nothing here. A file server that
mounts a `seaweedfs-csi` PVC and initiates nothing at all drops `to_cidrs` entirely and ships a
two-rule policy. Wider than one host, `to_cidrs = [var.deployment.network.host_cidr]` is the whole
LAN, which is also the only declaration of it anywhere ([`../README.md`](../README.md)).

### Build server / CI — the one that needs the API

```hcl
# argo-workflows: controllers and workflow pods, which create pods of their own.
module "egress_ci" {
  source = "../network/firewalls/egress"

  namespace      = "argo"
  name_prefix    = "argo-egress"
  allow_k8s_api  = true                                # controllers/executors talk to the apiserver
  to_namespaces  = ["kube-auth"]                       # the outpost fronting argo-wf
  allow_internet = true                                # git over SSH/HTTPS, package + module downloads
  to_cidrs       = [var.deployment.network.host_cidr]  # anything reached by its published name
}
```

```
1. ns argo, no ports                   (self)
2. ns kube-system: k8s-app=kube-dns, UDP+TCP/53
3. ns kube-auth, no ports
4. TCP/443  -> 10.96.0.1/32            (the API Service ClusterIP)
5. TCP/6443 -> the control-plane addresses
6. ipBlock 0.0.0.0/0 except the four private ranges
7. ipBlock 192.168.0.0/24
```

Rule 7 is the LAN, and the LAN is *not* how a CI job reaches the registry. A job pulling
`harbor.<domain>` dials the gateway VIP, which kube-proxy DNATs to the gateway's data plane pod in
`kube-network` before the policy chain runs — so rule 7 misses it and no CIDR can cover it; the
peer is `egress_peer` on `gateway.networking.k8s.io/gateway-name`, port 443 (measured, see "Things
that bite"). Dialling the registry by its cluster name (`harbor-core.devops-harbor.svc`) *is* a
namespace peer with no CIDR needed, but it is plain HTTP on :80 — no cert, so not what a container
runtime wants for a pull. Reach for the peer builder, not the LAN.

## Things that bite

- **A published hostname is not a namespace peer — and not a CIDR either.** Anything reached as
  `app.<domain>` lands on the gateway VIP, which DNATs to the gateway's data plane pod *in its own
  namespace* before the policy chain runs. Measured 2026-09-17: `to_cidrs = ["192.168.0.100/32"]`
  on harbor-core (the private gateway's VIP, from the live Service) permitted nothing, while the
  deny record named `kube-network/private-private-6f99f96d5f-*:443` as the flow the policy sees.
  The peer is the data plane pod on its port — [`../egress_peer`](../egress_peer/README.md).
- **`allow_internet` excludes RFC1918 by design**, so it never covers a NAS, the LAN, or LAN
  discovery — name the CIDR you mean.
- **Only selected pods are restricted.** Egress from a pod is denied-by-default once *some* policy
  selects it for `Egress`. Pods no policy selects stay wide open, so a `pod_selector`-scoped call
  tightens its own pods and leaves the rest of the namespace alone.
- **`allow_k8s_api` is two rules, and both fail closed.** `ports` is shared by every peer in a
  rule, so no single rule can cover both a ClusterIP and a node address — one of the two would
  match nothing. Both peer sets come from live reads (the Service, its Endpoints), and an empty
  read drops that rule instead of rendering a `to`-less one, which would mean *everywhere* on
  that port.
- **A ClusterIP peer needs the Service's port, and still probably won't match.** Nothing answers
  `10.96.0.1:6443`, so a ClusterIP peer with the backend's port is dead by construction; but even
  with the right port, this dataplane has already DNAT'd by the time policy runs. A dial to
  `10.96.0.1:443` is matched as `<node-ip>:6443` — same trap for a ClusterIP handed to
  `to_cidrs`, and the same trap for a **LoadBalancer VIP**, whose dial is matched as the endpoint
  *pod* (measured 2026-09-17; the VIP itself permitted nothing).
- **Two calls, one namespace, one name.** Explicit `name` wins over `name_prefix`, and identical
  explicit names collide; leave both unset for a generated unique name.
