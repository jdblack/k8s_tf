# firewalls

`NetworkPolicy` builders, one call = one object. Everything here governs **this repo's own
pods'** traffic; the Calico *tier* machinery (which is what the operator's own deny lives in)
is elsewhere, in `../whisker`.

## The rule of thumb

**A namespace-scoped curtain first, then holes.** Which direction the curtain drops is decided by
which way the namespace is dangerous:

1. **Risky *to* the cluster** — reaches the internet at large, runs untrusted code (`media`: plex,
   qbittorrent, torrent peers) → curtain **egress**.
2. **At risk *from* the cluster** — everything else depends on it, or it holds credentials
   (`kube-storage`, `longhorn-system`, the IdP) → curtain **ingress**.
3. **Self-talk stays open, and one namespace is one object.** Intra-namespace traffic is implicit in
   nearly every app, and a rule that has to be read is a rule that costs the reader. An LLM holds 26
   cells fine; a human sees a blurred forest and reads none of them — including the one that mattered.
   Every object here has to earn its place against that.
4. **A pod can be worse than its namespace** — dangerous to others, or exposed to something its
   namespace is not. Carve it out of the namespace's holes and give it its own profile, so its reach
   is readable from its own file. *How* depends on the direction: on **egress** the carve is a
   **move** — a pod-scoped call only adds to the floor, so the grant has to leave the namespace
   profile first (`harbor-trivy-egress`, `cert-manager-controller-egress`) — and on **ingress** it is
   an **exclusion** the module cannot express yet (below). Done: trivy, the cert-manager controller.
   Pending: `plex` and `qbittorrent` in `media`. The mirror case, a pod needing to be *tighter* than
   its namespace, is `longhorn-manager-metrics-ingress`.

Two consequences: **ordering between our own policies doesn't matter** — they union inside tier
`default` — and a brief cutover outage is accepted. Neither waives the two orderings that aren't
ours: the deferred read in `egress/data.tf` under a pending `depends_on`, and the operator's tier-100
`defaultAction: Deny`, which ends evaluation before tier `default` is reached.

**Limits to name.** Host-network pods (`blender`'s mDNS, `calico-node`, `metallb-speaker`) are not
reachable by a namespaced policy at all — only a `GlobalNetworkPolicy` sees them, and this layer
deliberately does not use one, so they stay outside the curtain. And an omitted `namespaceSelector`
on a peer defaults to `all()`, not to "same namespace": every peer below is written explicitly.

**The one missing mechanism is the ingress exclusion.** `pod_selector` renders `match_labels` only, so
a curtain cannot exclude a pod from itself (`matchExpressions` / `NotIn`); until the module grows that,
`media`'s plex/qbittorrent carve-out and `longhorn-system`'s namespace curtain both wait. Egress needs
no such mechanism — rule 4 there is a move between call sites.

| Module | What it renders |
|---|---|
| `egress/` | **Egress**, `pod_selector`-scoped or namespace-wide via the default: DNS always, own-namespace by default, plus namespace / API-server / cluster / internet / raw-CIDR peers. `policyTypes: ["Egress"]` only. |
| `egress_peer/` ([README](egress_peer/README.md)) | The same, for a **named** peer the base builder cannot express: namespace + pod selector + port. One call = one policy; used *alongside* an `egress` call, since netpols union. |
| `ingress/` ([README](ingress/README.md)) | **Ingress**, `pod_selector`-scoped or namespace-wide via the default: own-namespace and node-address floors by default, plus namespace / cluster / internet / raw-CIDR guests, plus `from_peers` for the narrow **namespace + pod selector + named ports** guest. `policyTypes: ["Ingress"]` only. One builder, not a pair — see below. |

Call sites, twenty egress policies live: `media` (`modules/media/egress.tf`, four — the namespace floor
below, plus an API grant for the NGF control plane and one for the NGF cert-generator *hook pod*, plus
the outpost's peer into `kube-auth`), `devops-harbor` (`modules/harbor/core/egress.tf`, three: DNS +
self for every pod the chart ships, `+ allow_internet` for `component=trivy`, and the gateway peer for
`component=core` — the first call in the repo to use `egress_peer`), `argo` (`modules/argo/core/egress.tf`,
four: a namespace *profile* — DNS + self + the API server + the internet, namespace-wide because argo-wf's
workflow pods are pods nobody declares — plus the same private-gateway peer on 443 for the three pods that
speak to it: repo-server (harbor's OCI charts), argo-cd's server and argo-wf's server (both OIDC issuers)),
**`kube-storage`
(`modules/storage/egress.tf`, four: the namespace profile, which here is the *closed floor* — own
namespace + DNS and nothing else, no internet — plus the API server for the CSI controller, the CSI
node DaemonSet's `driver-registrar` and `snapshot-controller`; and
`modules/storage/seaweedfs_admin/egress.tf`, one: the co-located outpost's peer into `kube-auth` on
:9000)**, **`kube-certificates` (`modules/cert_manager/egress.tf`, two: the namespace-wide base — DNS +
self + the API server, since every pod that chart renders including its `startupapicheck` hook Job is an
API client — plus `+ allow_internet` for the controller alone, which needs ACME and the Route53 API)**,
`blender`'s share (`modules/blender/egress.tf`, one — DNS plus its own namespace, nothing
else) and `vaultwarden` (`modules/vaultwarden/egress.tf`, the same two-rule shape, selected by the
Deployment's labels). The per-pod tables and the measured evidence behind each peer are in
[`../../media/README.md`](../../media/README.md),
[`../../storage/README.md`](../../storage/README.md),
[`../../cert_manager/README.md`](../../cert_manager/README.md),
[`../../vaultwarden/README.md`](../../vaultwarden/README.md) and a one-line note on each call —
`argo/core` has no README at all, so there its comments and the memory bank are the only copy.

**Per-pod closing is not namespace closing — hence a namespace-wide call.** A pod-scoped policy
governs the pods its selector matches and says nothing at all about the rest: an unselected pod falls
through to the namespace's profile, which is the Kubernetes default-allow one (`kns.<ns>`:
`egress: [{action: Allow}]`), i.e. LAN, gateway VIP, API server and internet. So "the namespace is
closed" means "the pods someone remembered to name are closed", and the next pod nobody names — a
debug box, a job, a new app's first commit — is wide open. Measured 2026-09-16: `media`'s hand-made
`utility` pod (no owner, label `app: utility`, selected by nothing) got **200** from the private
gateway VIP while every app beside it timed out. The fix is one more call rather than a selector
audit: an `egress` call with **no `pod_selector`** renders `podSelector: {}` — every pod in the
namespace, present and future. `modules/media/egress.tf` is the worked example, and it shows both
shapes that call can take:

- **The closed floor:** no `allow_*` / `to_*` set, so the entire grant is DNS + own namespace. This is
  the conservative shape — it removes the fall-through and hands out nothing new. It is a **no-op for
  every pod a per-pod call already selects**, because netpols union and every call in this repo keeps
  the self and DNS rules. `kube-storage` took this shape *as* its namespace profile on 2026-09-17: 28
  pods (SeaweedFS master/volume/filer/s3/admin/worker, the CSI controller and its two DaemonSets, the
  SSO outpost, `snapshot-controller`) whose measured reach over a 30-day window was in-namespace peers
  plus DNS, so there the floor and the profile are the same object — and the first namespace where
  that is true.
- **The namespace profile:** the floor plus whatever the namespace as a whole needs, e.g.
  `allow_internet = true` for `media`. One call then *is* the namespace's policy and the per-pod calls
  shrink to exceptions — cheaper to read, fewer objects to keep in sync. The price is real: a
  namespace-wide grant cannot be subtracted from, so **no pod in that namespace can be
  internet-less** (or whatever else the profile grants), present or future. `media` took this shape on
  2026-09-17 and deleted seven per-pod calls that had become no-ops under it.

Two consequences to carry either way: a namespace-wide call inverts the failure mode of a later call
that *drops* the self or DNS rule (the floor widens it, and nothing in the chain notices), and the
default is per namespace, so each namespace needs its own call. **The namespace-wide call goes in
first, not last** — it is the curtain, and the per-pod calls are the holes in it. Read the flow logs
*after* it lands to find the guests worth naming; the ones nobody names surface as breakage, which is
a cheaper signal than a namespace left open for a season. Note the union problem though: a
namespace-wide grant cannot be subtracted from, so a pod that needs to be tighter than its namespace
(rule 4 above) cannot be fixed here at all — it has to be excluded from the curtain's selector, which
needs `matchExpressions` the module does not render yet.

**And "the pods nobody names" includes the transient ones.** Hook Jobs, CronJobs, migration Jobs and
`kubectl run` one-offs are pods too, no per-pod selector in this repo names them, and a namespace-wide
call governs them the moment they appear. Measured 2026-09-16, two labeled `curlimages/curl` pods in
`media`, same second: the one labeled `job-name=ngf-nginx-gateway-fabric-cert-generator` (what NGF's
cert-generator hook pod actually carries) got `rc=28` against `https://10.96.0.1:443/api`, the one
labeled `app.kubernetes.io/name=nginx-gateway-fabric` (what `ngf-egress` selects) got `403`. The
chart's Job template sets no pod labels at all, so nothing but `job-name` matches it — that is the
2026-08-31 NGF-upgrade incident, re-armed by a namespace-wide policy rather than by a missing rule.
So before changing a floor, enumerate the namespace's *transient* pods too, and give hook pods their
own pod-scoped call: `job-name` is the only stable label one has, and a hook is only broken the next
time the chart moves. `media` now has that call (`ngf-cert-generator-egress`, verified back to `403`)
and does not hardcode the name — `modules/network/gateway` exports `cert_generator_job_name`, since
only the module that runs the `helm_release` can know it.

**Config-only modules never get a policy.** `harbor/mantle` is the worked example: it creates
Harbor projects and the OIDC client through the `goharbor/harbor` provider, so it holds no pods and
has no egress to govern — the policy lives in the module that owns the `helm_release`, because that
is the only module that can know the pods exist. Same for `monitoring/grafana_oidc`,
`network/dns/route53_record` and `argo/aoa_deployment`.

Two things are deliberately *not* here:

- **A `to_cidrs` shortcut to anything in-cluster.** Not a missing feature — a dead one. Egress is
  evaluated POST-DNAT, so the peer that matches is the *pod* the Service resolves to, never the
  Service IP and never a LoadBalancer VIP: `harbor-core` → the private gateway's VIP permitted
  nothing until the peer became the data-plane pod on 443 (`egress_peer`, measured 2026-09-17;
  same shape as the API-server ClusterIP finding in `egress/README.md`). CIDRs are for the LAN and
  real off-cluster hosts only.
- **A guest list that has to be read off three sources, not one.** The ingress direction costs more
  than egress because its guests are less visible: the flows, the live HTTPRoutes (which name the
  gateway as the peer and its ports), and Prometheus's `up{}` — a scrape holds its connection open, so
  it never appears in a flow at all. `kube-storage` got the first ingress call site on 2026-09-17 that
  way. A stalled rollout, a failing probe and a dead exporter are the signals that a guest was missed;
  that is the accepted cost of curtaining first, not a reason to wait for a complete list.

The ingress direction is the mirror image of everything above, so the builder differs where the
direction does, not where it does not: the same self rule, the same "one call = one object, callers
state intent" contract, the same namespace-label trick (`kubernetes.io/metadata.name`, so callers pass
names not selectors) — plus a floor this direction needs and egress never does, **the node
addresses** (`allow_nodes`, on by default, one `ipBlock` per node `InternalIP` read live from
`data.kubernetes_nodes`). kubelet probes and the apiserver's own calls into a pod originate on the
node's host network, so no `namespaceSelector` can match them: without that rule the pod answers
nothing, goes `NotReady` and the rollout stalls. It is the ingress answer to losing DNS. And one
asymmetry that *removes* something: there is no service-CIDR peer here, because DNAT rewrites the
**destination** — a guest's port is the pod's port.

**Why one ingress builder and two egress ones.** `ingress/` carries the peer shape itself, as
`from_peers`: one guest per rule with an optional pod selector and its own ports. The egress split
happened because harbor needed the narrow shape the day the base builder shipped, and a second module
was the smallest change that unblocked it; the ingress half got the same treatment before any caller
existed, and the cost showed up immediately — the two renderers diverged, and `ingress_peer`'s node
floor rendered as **empty `from {}` peers**, which in NetworkPolicy means *from anywhere*. That is the
argument against duplicating a renderer to serve one extra list: fold it into the builder that owns the
floors, where there is exactly one place for a rule's peer blocks to go wrong. `egress_peer` stays for
now only because five call sites use it and moving live `NetworkPolicy` objects buys nothing; if the
egress direction is ever revisited, the same fold is the shape to reach for.

**Reaching the LAN.** `deployment.network.host_cidr` (tfenv) is the only declaration of the LAN
anywhere — nothing in-cluster stores a netmask — so an egress call site passes it in as an
ordinary CIDR peer: `to_cidrs = [var.deployment.network.host_cidr]`. Inside an app module the
stack has to pass it down first. A single off-cluster host is the same shape at a narrower mask:
`to_cidrs = ["192.168.0.20/32"]`.

See `../README.md` for the namespace layout and `.clinedocs/calico-netpols.md` for
the tier rules that decide whether any of this traffic survives `calico-system`.
