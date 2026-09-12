# `policy` — the single NetworkPolicy renderer

Turns explicit **rule objects** into one typed `kubernetes_network_policy_v1`.
This is the only place in the library that translates rules → resource; the
public presets ([`basic_internet`](../basic_internet/README.md),
[`limited_ingress`](../limited_ingress/README.md),
[`allow_api`](../allow_api/README.md)) and any bespoke caller just build the
rule lists and call this, so the render logic (and its drift-visibility
properties) exists once.

## Inputs

| Var | Meaning |
|---|---|
| `name`, `namespace` | the NetworkPolicy's identity (name must be unique per namespace) |
| `pod_selector` | which pods it applies to (empty = `podSelector: {}` = whole namespace) |
| `policy_types` | subset of `["Ingress", "Egress"]` |
| `ingress_rules` / `egress_rules` | the rule lists |

## Rule shape (same for both directions)

```hcl
{
  peers = [
    { namespace_selector = { "kubernetes.io/metadata.name" = "kube-network" } },
    { namespace_selector = {...}, pod_selector = { "k8s-app" = "kube-dns" } },
    { ip_block = { cidr = "0.0.0.0/0", except = ["10.0.0.0/8"] } },
  ]
  ports = [{ protocol = "TCP", port = 6443 }]   # optional; omitted = any port
}
```

`ingress_rules` → `spec.ingress[].from[]` (source peers); `egress_rules` →
`spec.egress[].to[]` (destination peers). A peer with only a
`namespace_selector` means "any pod in that namespace"; add a `pod_selector`
to narrow it. `ip_block.except` is rendered only when non-empty (so the API
doesn't normalise an empty list into a perpetual diff).

Rule lists are typed `any`, not `list(any)`: rule/peer shapes differ between
entries and `list(any)` would force them all to the same type.

## Why typed, not `kubectl_manifest`

See [`basic_internet/security.tf`](../basic_internet/security.tf) — a
`kubectl_manifest`-backed NetPol edited out-of-band once silently became
allow-all while `tofu plan` reported no changes.
