# `whisker` — Calico Whisker flow-log UI, exposed + protected

Publishes the Calico **Whisker** flow-log UI at `whisker.<domain>` the same way
the media apps are published — HTTPS on the shared **private** gateway, fronted
by an **authentik proxy outpost** so access is SSO-gated by group membership —
and locks the flow data down in-cluster.

## What it renders

| Piece | From | Purpose |
|---|---|---|
| authentik proxy provider + application + outpost + token | `auth/authentik/proxy_app` | SSO gate; app bound to `group_name` |
| outpost Deployment/Service (`<outpost_service>`, :9000) in `namespace` | `auth/authentik/outpost` | authenticates, then proxies to whisker |
| ListenerSet (HTTPS, cert) + HTTPRoute → the **outpost** | `gateway/expose` | `whisker.<domain>` on the private gateway |
| pod-scoped ingress policy on the **whisker** pods | `firewalls/limited_ingress` | only the outpost (same ns) may reach `whisker:8081` |
| pod-scoped ingress policy on the **goldmane** pods | `firewalls/limited_ingress` | same-ns + node CIDR (Felix is hostNetwork) |

## The netpols — and what the operator already does

The tigera-operator **already** ships pod-scoped netpols in `calico-system`:

- **`whisker`** — `podSelector=whisker`, `policyTypes: [Ingress, Egress]` with
  **no ingress rules** → deny-all *pod* ingress. (Port-forward still works:
  that traffic is host-sourced and bypasses pod policy.) So no other namespace
  could already read `whisker:8081`.
- **`goldmane`** — `podSelector=goldmane`, one ingress rule with **ports 7443
  and no `from`** → allows **any** source on 7443 (Felix runs on every node).
  Kubernetes NetworkPolicies only *union*, so this **cannot be tightened from
  here** — `goldmane:7443` stays readable by any pod. Treat the flow API as
  cluster-visible; protect it by other means if that matters.

So this module adds only what the operator's rules don't:

- **`whisker-ingress`** — unions the **outpost** (same namespace) into whisker's
  ingress, which the operator's deny-all otherwise blocks. Every other
  namespace stays denied.
- **`whisker-outpost-egress`** — the outpost's own policy is `Egress`-only *and
  default-deny* (kube-auth:9000). In media the namespace-wide `basic_internet`
  posture supplies same-ns + DNS; in `calico-system` there deliberately is no
  such policy (a namespace-wide egress default-deny there would break Calico's
  own control plane). So we open exactly what the outpost needs: DNS + whisker.

`lan_cidrs` is accepted for parity with the other network submodules but is not
used — see the goldmane note above.

## Notes

- The outpost is co-located in `calico-system`, so the outpost → whisker hop is
  same-namespace and needs no cross-namespace policy.
- Whisker's UI pulls flows as a live stream; if the proxy layer buffers it the
  page will load but the flow list will stay empty (that's the proxy, not
  whisker). Test after applying.
- There is no upstream calico/whisker tile icon, so `icon` defaults to null.
