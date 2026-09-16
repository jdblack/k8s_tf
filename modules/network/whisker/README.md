# `whisker` — Calico Whisker flow-log UI, exposed + protected

Publishes the Calico **Whisker** flow-log UI at `whisker.<domain>` the same way
the media apps are published — HTTPS on the shared **private** gateway, fronted
by an **authentik proxy outpost** so access is SSO-gated by group membership —
and locks the flow data down in-cluster.

**Read `tier.tf` before touching policy here.** Since tigera-operator `v3.32.2`
the operator's rules live in a policy *tier* that outranks the tier our
NetworkPolicies compile into, which makes the k8s policies below inert and means
the Calico CRs in `tier.tf` are what actually gates this app.

## What it renders

| Piece | From | Purpose |
|---|---|---|
| authentik proxy provider + application + outpost (Deployment/Service `<outpost_service>`, :9000, in `namespace`) | `auth/authentik/proxy_outpost` | SSO gate; app bound to `group_name`, outpost authenticates then proxies to whisker |
| ListenerSet (HTTPS, cert) + HTTPRoute → the **outpost** | `gateway/expose` | `whisker.<domain>` on the private gateway |
| 3× Calico `NetworkPolicy` CR, `spec.tier: calico-system` | `tier.tf` | **the effective policy**: outpost egress, gateway → outpost, outpost → whisker |
| pod-scoped ingress policy on the **whisker** pods | `firewalls/limited_ingress` | currently inert (see tier) |
| pod-scoped **egress** policy on the outpost pods | `firewalls/policy` | currently inert (see tier) |

## The netpols — and what the operator already does

The tigera-operator **already** ships pod-scoped netpols in `calico-system`:

- **`whisker`** — `selector: k8s-app == 'whisker'`, `types: [Ingress, Egress]` with
  **no ingress rules** → deny-all *pod* ingress. (Port-forward still works:
  that traffic is host-sourced and bypasses pod policy.) So no other namespace
  could already read `whisker:8081`. Note the operator ships no namespace-wide
  egress posture for `calico-system`, deliberately: a namespace-wide egress
  default-deny there would break Calico's own control plane.
- **`goldmane`** — `selector: k8s-app == 'goldmane'`, one ingress rule with
  **port 7443 and no `source`** → allows **any** source on 7443 (Felix runs on
  every node). Calico rules only *union*, so this **cannot be tightened from
  here** — `goldmane:7443` stays readable by any pod. Treat the flow API as
  cluster-visible; protect it by other means if that matters.

So this module adds only what the operator's rules don't, in the tier (see
below) — and each rule is pod-scoped, so the gateway hop is narrower than the
namespace-wide equivalent a k8s policy would need.

## Why `tier.tf` exists

tigera-operator `v3.32.2` created the tier `calico-system` (`order: 100`,
`defaultAction: Deny`) and moved its own rules into it, including
`calico-system.default-deny` (`selector: k8s-app != 'calico-apiserver'`, no
rules). Tiers are evaluated in order and an earlier tier's end-of-tier DROP
pre-empts every later one; k8s NetworkPolicies all compile into `default`
(`order: 1000000`). Net effect, verified in iptables: everything in
`calico-system` except `calico-apiserver` gets dropped for the *whole* of both
directions, and nothing this module wrote reached the data path any more.
Symptom was `https://whisker.<domain>` → `code=000` after the upgrade, with the
gateway itself healthy, plus the outpost's long-lived authentik websocket dying
and never reconnecting (its DNS and its `authentik-server` egress are dropped
too, so the outpost cannot even fetch its config; restarting the pod while the
traffic is still dropped does not help). **A restart *is* required once the tier
lands**: the outpost backs off exponentially on its failed config fetches and
does not retry on its own timescale, so it holds no `:9000` listener and the
gateway reports an upstream RST (`502`) rather than a hang — the policy is
passing by then, the process just is not listening. Only a Calico `NetworkPolicy` CR with
`spec.tier: calico-system` can allow anything there — a k8s netpol cannot,
however it is written. Hence three CRs, one per hop:

1. **`whisker-outpost-egress-tier`** — outpost egress: DNS (UDP+TCP 53, kube-dns
   post-DNAT), `authentik-server` pods :9000 (post-DNAT, Service is :80),
   `whisker` pods :8081.
2. **`whisker-outpost-ingress-tier`** — NGF's data plane pod for this Gateway
   (`gateway.networking.k8s.io/gateway-name` label, in `gateway_namespace`) →
   outpost :9000. Nothing selected the outpost for ingress before, so this hop
   was unpoliced and worked by default.
3. **`whisker-ingress-tier`** — outpost → `whisker` pods :8081.

The outpost's `:9443` (https) listener is deliberately left closed: `expose`
routes to `:9000`.

The k8s policies are kept rather than deleted: they are the portable statement of
intent and would be load-bearing again if a future operator stopped shipping the
tier, but **they are not what protects this app today**.

## Notes

- The outpost is co-located in `calico-system`, so the outpost → whisker hop is
  same-namespace (in the tier CRs that is a `selector` with no
  `namespaceSelector`).
- On a **fresh cluster** `core` has to have applied the tigera-operator release
  (which creates the tier) before `mantle` applies these CRs, or the apply fails
  with a missing-tier admission error. Applying `core` first — the documented
  order — covers it; just re-apply `mantle` if you race it.
- Whisker's UI pulls flows as a live stream; if the proxy layer buffers it the
  page will load but the flow list will stay empty (that's the proxy, not
  whisker). Test after applying.
- **The live CRs were hand-applied 2026-09-16 and are not in Terraform state
  yet.** `mantle`'s apply was blocked by an unrelated authentik data-source
  failure, so the three CRs were `kubectl apply`ed from their rendered YAML and
  whisker was verified working that way. Import them (or delete and let `mantle`
  recreate them) before trusting `plan` here:
  `tofu -chdir=stacks/mantle import 'module.whisker.kubectl_manifest.tier_outpost_egress'
  'crd.projectcalico.org/v1//NetworkPolicy//whisker-outpost-egress-tier//calico-system'`
  — same shape for `tier_outpost_ingress` / `tier_whisker_ingress`;
  `kubectl_manifest`'s import ID is `apiVersion//Kind//name//namespace`.
- **Verified 2026-09-16** (hand-applied CRs): an unauthenticated
  `https://whisker.<domain>/` → `302` to `/outpost.goauthentik.io/start?rd=…` → the
  authentik flow `…/if/flow/default-authentication-flow/?scope=…ak_proxy` with HTTP
  **200** and `ak-flow-executor` in the body, so hops 1-2 and the SSO redirect are
  live. Hop 3 (outpost → `whisker:8081`) only carries traffic *after* a login, so
  confirm it with one browser sign-in end to end.
- There is no whisker-specific tile icon in any icon set (the Calico repo ships
  only a React component, not an SVG), so `icon` defaults to the **Calico** brand
  mark from the selfh.st icon set via jsDelivr (Whisker is a Calico component).
  Override `var.icon` to change it; `null` leaves the tile iconless.
