# ingress

One call renders exactly one `NetworkPolicy`, `policyTypes: ["Ingress"]`. Callers state intent; the
module decides selectors, CIDRs and rule order. Everything the caller does not name is **denied**, so
this is the opposite of a quiet tightening — an ingress policy that selects a pod *is* deny-all-inbound
for it, and the guest list is the whole point. The first one is live: `kube-storage-baseline-ingress`
(`storage/ingress.tf`, 2026-09-17). Wiring state and the two
directions side by side: [`../README.md`](../README.md).

```hcl
# Real caller shape: a gateway-fronted namespace, reached by the gateway's data plane and by Prometheus.
module "ingress_seaweedfs_admin" {
  source = "../network/firewalls/ingress"

  namespace = var.namespace
  name      = "seaweedfs-admin-ingress"

  from_namespaces = ["monitoring"]   # ServiceMonitor scrapes the whole namespace, any port
  from_peers = [{                    # the gateway's data-plane pod, on the pod's own port
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 9333 }]
  }]
}
```

Renders four rules, in this order:

```
1. pods in kube-storage, no ports                  (self)
2. ns monitoring, no ports
3. ipBlock <node-internal-ip>/32, one per node      (allow_nodes, on by default)
4. ns kube-network: gateway-name=private, TCP/9333  (the guest)
```

## Variables

| Variable | Type | Default | Means |
|---|---|---|---|
| `namespace` | `string` | — | Namespace whose pods this governs, and where the policy lives |
| `pod_selector` | `map(string)` | `{}` | Governed pods — the **destination**. `{}` = every pod in the namespace |
| `name` | `string` | `null` | `metadata.name`; wins outright over `name_prefix` |
| `name_prefix` | `string` | `null` | Generated name, `<prefix>-<8 hex>`. Default prefix is `namespace-ingress` |
| `allow_namespace` | `bool` | `true` | This namespace's own pods — the self rule |
| `from_namespaces` | `list(string)` | `[]` | Whole-namespace guests, by name, any pod, any port. A name given twice collapses to one rule. Shorthand for a `from_peers` entry with neither selector nor ports |
| `allow_nodes` | `bool` | `true` | Each node's `InternalIP`, any port: kubelet probes and the apiserver's calls into a pod start there. The direction's floor |
| `allow_cluster` | `bool` | `false` | The pod CIDR wholesale — any pod in the cluster. Rare; prefer `from_namespaces` / `from_peers` |
| `allow_internet` | `bool` | `false` | Public source addresses: `0.0.0.0/0` except RFC1918 + link-local. For a WAN-forwarded `LoadBalancer` |
| `from_cidrs` | `list(string)` | `[]` | Extra source CIDRs, one `ipBlock` peer each (the LAN, a NAS, one host, a node IP). Duplicates collapse |
| `from_peers` | `list(object)` | `[]` | `{ namespace, pod_selector = <labels or null>, ports = [{port, protocol}] }` — one rule per guest, rendered last, each carrying its own ports. The narrow shape: which pods, which port |

`allow_*` are the switches; `from_*` take explicit guest lists. One call = one object, so a namespace
with two very different postures gets two calls, scoped with `pod_selector`, rather than one wide one.

## Always on

**Self.** Every pod in `var.namespace`, rendered first, on by default: intra-namespace traffic is
implicit in nearly every app, so the burden sits with the caller who genuinely wants a pod walled off
from its own namespace (`allow_namespace = false`).

**The nodes.** One `ipBlock` peer per node `InternalIP`, on by default. This has no egress counterpart
because that direction does not need it: **kubelet health probes and the apiserver's own calls into a
pod originate on the node's host network**, not on a pod, so no `namespaceSelector` can match them.
Without it a governed pod answers nothing, goes `NotReady`, and a rollout stalls — the ingress
direction's version of losing DNS, which is why it is a floor rather than a curated switch. Read live
from `data.kubernetes_nodes`, so nothing hardcodes an address; an empty read drops the rule instead of
rendering it peerless, because a `from`-less rule means *from anywhere*.

Neither is needed for *replies*: an established flow is not re-evaluated against policy. An ingress rule
is for the connections others **initiate** into these pods; what the pod dials out is the
[`egress`](../egress/README.md) direction's business, and the two are separate objects.

## What an empty call renders

A call that names no guest (`from_namespaces = []`, no other switch, `allow_namespace = false`) renders
`ingress = []` — a bare `Ingress` policy, i.e. **deny-all inbound**. Deliberately: for this direction
there is no "empty rule means from anywhere" footgun to disarm, and no default guest list is safe to
hand out. The switch is the call itself.

## Typical profiles

### Gateway-fronted app — the gateway pod, not the gateway namespace

The shared gateways' data planes live in `kube-network`, and naming that whole namespace opens the app
to every pod in it on every port — the platform's own components, but a blunt guest list all the same.
`from_peers` names the pod and the port it needs:

```hcl
module "ingress_app" {
  source = "../network/firewalls/ingress"

  namespace    = var.namespace
  name         = "app-ingress"
  pod_selector = { "app.kubernetes.io/name" = "my-app" }

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 8080 }]      # the POD's port, not the Service's
  }]
}
```

One pod, one port, in the same object as the floors. The alternative — `from_namespaces =
[var.gateway_namespace]` — is the fallback when the gateway's pod labels are not something you can rely
on: it holds 13 pods in this cluster (both data planes, both NGF control planes, the MetalLB
controller, external-dns, tigera-operator; the MetalLB *speakers* are hostNetwork and no
`namespaceSelector` can match them anyway), which is more than the app needs on ports it mostly does
not listen on.

A `from_peers` guest with no `pod_selector` is that same whole-namespace grant spelled the long way —
legal, but then say `from_namespaces` and mean it.

### Namespace reached from outside the cluster

A LAN client or a public peer is never a pod, so no `namespaceSelector` can match it — that is what the
CIDR guests are for. A `LoadBalancer` with `externalTrafficPolicy: Local` keeps the real client address,
so the guard is the client's range:

```hcl
module "ingress_torrent" {
  source = "../../network/firewalls/ingress"

  namespace      = var.namespace
  name           = "qbittorrent-ingress"
  pod_selector   = { "app.kubernetes.io/name" = "qbittorrent" }
  allow_internet = true                                  # WAN-forwarded peer addresses
  from_cidrs     = [var.deployment.network.host_cidr]    # LAN clients, the router's own range
}
```

`externalTrafficPolicy: Cluster` is the other half of that: kube-proxy SNATs the client to a **node**
address, so a CIDR guest misses and `allow_nodes` is what admits it. That measured asymmetry —
`etp=Cluster` LoadBalancers (blender samba, WireGuard) break under a firewall while `etp=Local` (media,
both gateways) pass — is in `.clinedocs/calico-netpols.md`.

## Things that bite

- **Probes are the first casualty, and they read as an application bug.** `allow_nodes` is on by
  default precisely because a pod-scoped ingress policy with no node grant has working app traffic and
  dead liveness/readiness probes. Turn it off only after checking what breaks.
- **The node grant admits anything on a node's host network**, on any port — `calico-node`,
  `metallb-speaker`, `node-exporter`, a `hostNetwork` debug pod. That is the price of having the pod
  reachable at all; `pod_selector` keeps it from covering pods nobody asked about, and a `/32` in
  `from_cidrs` is the narrower shape when you know the one address you mean.
- **`allow_internet` is public sources only.** RFC1918 and link-local are subtracted, which keeps it off
  the LAN, off the nodes and off every pod — and also means a LAN client is *not* covered by it.
- **A guest's ports are the destination pod's ports, not the Service's.** kube-proxy DNATs before
  ingress is evaluated, so `ports = [{ port = 80 }]` against a Service fronting `:9000` permits nothing
  — the same POST-DNAT trap as the egress direction, in the other seat.
- **`pod_selector` scopes the destination, never the guest.** A guest's own pods are named in
  `from_peers`, where the selector sits *inside* a `from` entry beside the namespace — that pairing is
  an AND in one peer. A bare `podSelector` on its own is not a narrowing: with no `namespaceSelector`
  beside it, it means *this policy's own* namespace, i.e. the self rule.
- **netpols only union.** This can add to what a chart- or operator-shipped `Ingress` policy already
  allows and can never subtract from it; pods no policy selects are unaffected, so a call that forgets
  `pod_selector` covers the whole namespace, present and future (`podSelector: {}`).
- **Host-network pods are outside pod policy entirely.** One can be neither selected by these policies
  nor admitted by a `namespaceSelector` guest — only by its node address.
- **Measure before you cut over.** Whisker never emits a flow for work that is not being done: a quiet
  guest list is the kind of quiet the `media` egress floor was measured around
  (`.clinedocs/flow-logs.md`), and probes plus webhook callbacks are the flows that will not show up as
  app traffic and will show up as a stalled rollout instead.
- **Several calls, one namespace, one name each.** Explicit `name` wins over `name_prefix`, and
  identical explicit names collide; leave both unset for a generated unique name.

## Narrow guests: `from_peers`

The explicit guest list, and the only place a caller can say **which pods** in the guest namespace and
**which ports** — a `from_namespaces` guest is the whole namespace on every port, and `allow_cluster`
is every pod on earth. One guest per rule, because `ports` belongs to the rule in the rendered spec, not
to the guest: two guests with different ports are two rules, not one rule with two peers.

It does one thing `from_namespaces` cannot, so reach for it whenever the answer is a pod rather than a
namespace. Three ways to get it wrong:

- **An empty `ports` means every port** into that guest. Say the port; that is the point.
- **The selector is the *source* pods' label, not their Service name.** NGF stamps
  `gateway.networking.k8s.io/gateway-name`; a chart's own app label is the usual one; a Helm hook Job's
  pods carry only `job-name` and the Job controller's labels (`.clinedocs/calico-netpols.md`).
- **A guest with no `pod_selector` is a whole-namespace guest** written the long way — legal, but
  `from_namespaces` says it better.

```hcl
from_peers = [
  {                                                      # the gateway data plane, on the pod's port
    namespace    = "kube-network"
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = "private" }
    ports        = [{ port = 8080 }]
  },
  {                                                      # Prometheus only: 18 pods in monitoring,
    namespace    = "monitoring"                          # this is the one that scrapes
    pod_selector = { "app.kubernetes.io/name" = "prometheus" }
    ports        = [{ port = 9113 }]
  },
]
```
