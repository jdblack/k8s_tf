# `limited_ingress` — ingress firewall with a namespace/CIDR guest list

Restrict who may open connections *into* this namespace. Pods in the namespace
accept ingress only from the namespaces listed in `allowed_ingress_namespaces`
and the source CIDRs in `allowed_ingress_cidrs`; everything else is dropped.

> **Direction:** Ingress only. Pair it with
> [`basic_internet`](../basic_internet/README.md) for the matching egress
> posture.

## When to use

The natural profile for anything **served through a shared gateway**: the
gateway data planes live in `kube-network` and proxy into your namespace, so
that namespace must appear in the list, plus `monitoring` if Prometheus scrapes
you. Example from seaweedfs:

```hcl
module "firewall" {
  source = "../../network/firewalls/limited_ingress"

  namespace = var.namespace   # e.g. "kube-storage"
  allowed_ingress_namespaces = [
    var.namespace,   # seaweed components talk to each other
    "kube-network",  # private-gateway data plane fronts S3/admin/master for LAN clients
    "monitoring",    # Prometheus ServiceMonitor scrapes
  ]
  # only when the namespace is also reached directly via a LoadBalancer.
  # A LAN-only peer is `{ cidr = "192.168.0.0/24" }`; a LoadBalancer that is
  # ALSO internet-exposed (WAN port-forward, where the source is a public peer
  # address) uses "everything outside the cluster":
  # allowed_ingress_cidrs = [
  #   { cidr = "0.0.0.0/0", except = ["10.244.0.0/16", "10.96.0.0/12"] },
  # ]
}
```

Membership rules of thumb:

- always list the namespace itself if its pods talk to each other
  (`[var.namespace]` = same-namespace-only, the former `namespace_only` module)
- list `kube-network` if it is exposed via a ListenerSet/HTTPRoute
- list `monitoring` if it has ServiceMonitors you want scraped
- add CIDRs to `allowed_ingress_cidrs` if the namespace has a **LoadBalancer**
  reached directly from outside the cluster (e.g. media's plex / torrent /
  gateway LBs). A LAN client or an internet peer is not a pod, so no
  `namespaceSelector` will ever match it — this peer type is what keeps the LB
  reachable while every cluster pod stays denied. Use
  `{ cidr = "0.0.0.0/0", except = [<cluster pod/service CIDRs>] }` when the LB
  is also WAN-exposed (port-forwarded), since then the source is a public
  address, not the LAN. Note the `except` ranges must sit inside `cidr`.
- sizes for the `except` list are the cluster's own ranges — Calico pods
  `10.244.0.0/16` and ClusterIPs `10.96.0.0/12` here — so every *other* pod is
  denied while external sources pass

## Semantics

- Scope: `podSelector: {}` (whole namespace) unless `pod_selector` is set, in
  which case the policy applies only to those pods. `policyTypes: ["Ingress"]`.
- Each `allowed_ingress_namespaces` entry becomes one `namespaceSelector` peer
  (any pod in that namespace may connect, any port); each `allowed_ingress_cidrs`
  entry becomes one `ipBlock` peer (any host whose source IP is in that entry's
  `cidr` and outside its `except`, any port). All peers live in a single ingress
  rule.
- **Both** lists empty renders a bare ingress policy = **deny all ingress**
  (deliberately no "empty rule means allow all" footgun).
- Rendered with the typed `kubernetes_network_policy_v1` resource (drift-visible).

### `pod_selector` — pod-scoped supplement

`pod_selector` scopes the policy to specific pods (the **destination**). Use it
to let an extra namespace reach **one** target without opening the whole
namespace to it: call the module once namespace-wide with a tight guest list,
then a second time with the target's labels and the extra namespace. Because
NetworkPolicies union, the target gets both; everything else gets only the
first. **Media** uses this so `kube-network` (which hosts the internet-facing
shared gateways) may reach only plex:

```hcl
# namespace-wide: media + VPN + LAN/internet, deliberately NO kube-network
module "firewall_ingress" {
  source                     = "../network/firewalls/limited_ingress"
  namespace                  = var.namespace
  policy_name                = "namespace-ingress"
  allowed_ingress_namespaces = [var.namespace, "kube-network-vpn"]
  allowed_ingress_cidrs = [
    { cidr = "0.0.0.0/0", except = ["10.244.0.0/16", "10.96.0.0/12"] },
  ]
}

# pod-scoped supplement: kube-network -> the plex pods only
module "firewall_ingress_plex" {
  source                     = "../network/firewalls/limited_ingress"
  namespace                  = var.namespace
  policy_name                = "namespace-ingress-plex"
  pod_selector               = { "app.kubernetes.io/name" = "plex-media-server" }
  allowed_ingress_namespaces = ["kube-network"]
}
```

Each call needs its own `policy_name` (names are per-namespace). Note the
scoping is on the **destination** — a peer's own `podSelector` would select the
*source* pods in the guest namespace instead.

## Naming (renamed from `allow_ingress`)

Renamed `allow_ingress` → `limited_ingress` (2026-09): the old name read like a
blanket "allow ingress" when the module is actually a lockdown with a guest
list. The rename is **docs/paths only** — the module call name, the resource
label (`limit_ingresses`), and the default `policy_name` (`namespace-firewall`)
are unchanged, so it causes **no** NetworkPolicy create/destroy.

## Relationship to the removed `namespace_only` module

`namespace_only` ("only the same namespace may reach this namespace", rendered
via `kubectl_manifest`) was deleted when this module arrived. It is the special
case `allowed_ingress_namespaces = [var.namespace]` — same idea, now
parameterized and drift-visible.

## See also

- [`basic_internet`](../basic_internet/README.md) — the matching egress module.
- [`firewalls/README.md`](../README.md) — decision table and composition notes.
