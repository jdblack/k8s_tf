# Firewalls

Reusable NetworkPolicy helpers. Every module here ultimately renders a typed
`kubernetes_network_policy_v1` resource (NOT `kubectl_manifest`) so that
`tofu plan` diffs against live state and flags out-of-band drift — a
kubectl-managed NetPol whose spec was edited behind tofu's back was previously
invisible to planning (this actually happened to the seaweedfs policy).

The presets below build explicit **rule objects** and hand them to
[`policy/`](policy/README.md), which is the single renderer — so the
rule → resource translation (and its drift-visibility) lives in one place.

## Decision table

| Module | Direction | Scope | What it allows | Key variables |
|---|---|---|---|---|
| [`basic_internet`](basic_internet/README.md) | **Egress** | whole namespace | internet + DNS + same-namespace, plus opt-in carve-outs (kube-network services, k8s API, ipBlocks) | `allow_internet`, `allow_dns`, `allow_to_ns`, `allow_to_services`, `allow_to_k8sapi`, `egress_allow_ip_blocks` |
| [`limited_ingress`](limited_ingress/README.md) | **Ingress** | whole namespace (or a `pod_selector` subset) | connections from a configured list of namespaces + source CIDRs (LAN/LB clients, or `0.0.0.0/0` minus the cluster ranges); everything else denied | `allowed_ingress_namespaces`, `allowed_ingress_cidrs`, `pod_selector` |
| [`allow_api`](allow_api/README.md) | **Egress** | **pod subset** (label selector) | only the selected pods may egress to the k8s API server (+DNS) | `pod_selector` |

All three target `podSelector: {}` (the whole namespace) **except** `allow_api`,
which narrows to its `pod_selector`; `limited_ingress` also takes an optional
`pod_selector` so a namespace-wide call can be supplemented by a pod-scoped one
(see [its README](limited_ingress/README.md#pod_selector--pod-scoped-supplement)).

## Similar-feature cross-references

Two features in this library do the *same job at different scopes*, and their
docs point at each other:

- `basic_internet.allow_to_k8sapi` — namespace-wide: *every* pod in the
  namespace may egress to the API server. Right call when the whole namespace
  is trusted API consumers (e.g. cert-manager, Argo CD). See
  [basic_internet → "Allowing the Kubernetes API"](basic_internet/README.md#allowing-the-kubernetes-api).
- `allow_api` — pod-scoped: *only* pods matching `pod_selector` may egress to
  the API server. Right call when a namespace is mostly apps that must NOT
  reach the API but happens to host one controller that must (e.g. the NGF
  control plane inside `media`). See
  [allow_api → "Why pod-scoped instead of allow_to_k8sapi?"](allow_api/README.md#why-pod-scoped-instead-of-basic_internetallow_to_k8sapi).

Rule of thumb: **namespace-wide API egress is the convenience, `allow_api` is
the lockdown** — prefer `allow_api` unless every workload in the namespace
legitimately calls the API.

## Composing policies

NetworkPolicies in Kubernetes are **additive (union)**, so this library is
meant to be combined, not picked one-per-namespace:

- `limited_ingress` + `basic_internet` = full posture for a gateway-fronted app
  (who may reach me + where I may go).
- `basic_internet` (API off) + `allow_api` = namespace lockdown with a single
  pod-scoped API exception.

Every module takes a `policy_name` (default `namespace-firewall` except
`allow_api`'s `allow-api-egress`); NetworkPolicy names are unique *per
namespace*, so give each policy in the same namespace a distinct name.

## History (names only — nothing is enforced by the old ones)

- **`namespace_only` is gone**, replaced by `limited_ingress` with
  `allowed_ingress_namespaces = [var.namespace]` — the same posture with a guest
  list, and typed instead of `kubectl_manifest`.
- **`allow_ingress` → `limited_ingress`** (2026-09). The old name read like a
  blanket "allow ingress" when the module is actually a lockdown with a guest
  list. Docs/paths only: the module call name, resource label and default
  `policy_name` did not move, so the rename caused no NetworkPolicy
  create/destroy. `allowed_ingress_cidrs` arrived at the same time, so a
  namespace whose LoadBalancer is reached from outside the cluster (where the
  source is never a pod) can stay open while every cluster pod is denied.
