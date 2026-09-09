# `allow_ingress` — ingress firewall with a namespace guest list

Restrict who may open connections *into* this namespace. Pods in the namespace
accept ingress only from the namespaces listed in `allowed_ingress_namespaces`;
everything else — other namespaces, LAN/host sources — is dropped.

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
  source = "../../network/firewalls/allow_ingress"

  namespace = var.namespace   # e.g. "kube-storage"
  allowed_ingress_namespaces = [
    var.namespace,   # seaweed components talk to each other
    "kube-network",  # private-gateway data plane fronts S3/admin/master for LAN clients
    "monitoring",    # Prometheus ServiceMonitor scrapes
  ]
}
```

Membership rules of thumb:

- always list the namespace itself if its pods talk to each other
  (`[var.namespace]` = same-namespace-only, the former `namespace_only` module)
- list `kube-network` if it is exposed via a ListenerSet/HTTPRoute
- list `monitoring` if it has ServiceMonitors you want scraped

## Semantics

- Whole namespace: `podSelector: {}`, `policyTypes: ["Ingress"]`; each entry in
  `allowed_ingress_namespaces` becomes one `namespaceSelector` peer (any pod in
  that namespace may connect, any port).
- An **empty** list renders a bare ingress policy = **deny all ingress**
  (deliberately no "empty rule means allow all" footgun).
- Rendered with the typed `kubernetes_network_policy_v1` resource (drift-visible).

## Relationship to the removed `namespace_only` module

`namespace_only` ("only the same namespace may reach this namespace", rendered
via `kubectl_manifest`) was deleted when this module arrived. It is the special
case `allowed_ingress_namespaces = [var.namespace]` — same idea, now
parameterized and drift-visible.

## See also

- [`basic_internet`](../basic_internet/README.md) — the matching egress module.
- [`firewalls/README.md`](../README.md) — decision table and composition notes.
