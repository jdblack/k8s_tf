# Firewalls

Reusable NetworkPolicy helpers. Every module here renders a typed
`kubernetes_network_policy_v1` resource (NOT `kubectl_manifest`) so that
`tofu plan` diffs against live state and flags out-of-band drift — a
kubectl-managed NetPol whose spec was edited behind tofu's back was previously
invisible to planning (this actually happened to the seaweedfs policy).

## Decision table

| Module | Direction | Scope | What it allows | Key variables |
|---|---|---|---|---|
| [`basic_internet`](basic_internet/README.md) | **Egress** | whole namespace | internet + DNS + same-namespace, plus opt-in carve-outs (kube-network services, k8s API, ipBlocks) | `allow_internet`, `allow_dns`, `allow_to_ns`, `allow_to_services`, `allow_to_k8sapi`, `egress_allow_ip_blocks` |
| [`allow_ingress`](allow_ingress/README.md) | **Ingress** | whole namespace | connections from a configured list of namespaces; everything else denied | `allowed_ingress_namespaces` |
| [`allow_api`](allow_api/README.md) | **Egress** | **pod subset** (label selector) | only the selected pods may egress to the k8s API server (+DNS) | `pod_selector` |

All three are namespace-*selecting* (`podSelector: {}` targets every pod in the
namespace) **except** `allow_api`, which narrows to the pods matching its
`pod_selector`.

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

- `allow_ingress` + `basic_internet` = full posture for a gateway-fronted app
  (who may reach me + where I may go).
- `basic_internet` (API off) + `allow_api` = namespace lockdown with a single
  pod-scoped API exception.

Every module takes a `policy_name` (default `namespace-firewall` except
`allow_api`'s `allow-api-egress`); NetworkPolicy names are unique *per
namespace*, so give each policy in the same namespace a distinct name.

## `namespace_only` (removed)

An earlier module rendered "same-namespace ingress only". It was deleted once
`allow_ingress` arrived: same-namespace-only is just
`allow_ingress` with `allowed_ingress_namespaces = [<self>]`. `allow_ingress` is
the same idea with a guest list, and it uses the typed resource instead of
`kubectl_manifest`.
