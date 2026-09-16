# firewalls

`NetworkPolicy` builders, one call = one object. Everything here governs **this repo's own
pods'** traffic; the Calico *tier* machinery (which is what the operator's own deny lives in)
is elsewhere, in `../whisker`.

| Module | What it renders |
|---|---|
| `egress/` | Per-pod **egress**: DNS always, own-namespace by default, plus namespace / API-server / cluster / internet / raw-CIDR peers. `policyTypes: ["Egress"]` only. |
| `egress_peer/` ([README](egress_peer/README.md)) | The same, for a **named** peer the base builder cannot express: namespace + pod selector + port. One call = one policy; used *alongside* an `egress` call, since netpols union. |

Call sites, fourteen policies live: `media` (`modules/media/egress.tf`, four — the namespace floor
below, plus an API grant for the NGF control plane and one for the NGF cert-generator *hook pod*, plus
the outpost's peer into `kube-auth`), `devops-harbor` (`modules/harbor/core/egress.tf`, three: DNS +
self for every pod the chart ships, `+ allow_internet` for `component=trivy`, and the gateway peer for
`component=core` — the first call in the repo to use `egress_peer`), **`kube-storage`
(`modules/storage/egress.tf`, four: the namespace profile, which here is the *closed floor* — own
namespace + DNS and nothing else, no internet — plus the API server for the CSI controller, the CSI
node DaemonSet's `driver-registrar` and `snapshot-controller`; and
`modules/storage/seaweedfs_admin/egress.tf`, one: the co-located outpost's peer into `kube-auth` on
:9000)**, `blender`'s share (`modules/blender/egress.tf`, one — DNS plus its own namespace, nothing
else) and `vaultwarden` (`modules/vaultwarden/egress.tf`, the same two-rule shape, selected by the
Deployment's labels). The per-pod tables and the measured evidence behind each peer are in
[`../../media/README.md`](../../media/README.md),
[`../../storage/README.md`](../../storage/README.md),
[`../../vaultwarden/README.md`](../../vaultwarden/README.md) and a one-line note on each call.

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
default is per namespace, so each namespace needs its own call. **Add it last in a namespace, never
first:** where the pods are not yet covered per-pod, the closed floor is a cutover to DNS + self that
breaks every peer nobody has measured yet, and a profile that *grants* something re-opens a namespace
whose per-pod calls were written to deny exactly that. That is why the rollout below is per-namespace
and per-pod, and why `media` got its floor only after all ten of its workloads had been read off
measured flows.

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

- **Ingress.** A `NetworkPolicy` that types `Ingress` is a deny-all-inbound for the pods it
  selects, and there is no shape of ingress policy that is safe as a default.
- **A `to_cidrs` shortcut to anything in-cluster.** Not a missing feature — a dead one. Egress is
  evaluated POST-DNAT, so the peer that matches is the *pod* the Service resolves to, never the
  Service IP and never a LoadBalancer VIP: `harbor-core` → the private gateway's VIP permitted
  nothing until the peer became the data-plane pod on 443 (`egress_peer`, measured 2026-09-17;
  same shape as the API-server ClusterIP finding in `egress/README.md`). CIDRs are for the LAN and
  real off-cluster hosts only.

**Reaching the LAN.** `deployment.network.host_cidr` (tfenv) is the only declaration of the LAN
anywhere — nothing in-cluster stores a netmask — so an egress call site passes it in as an
ordinary CIDR peer: `to_cidrs = [var.deployment.network.host_cidr]`. Inside an app module the
stack has to pass it down first. A single off-cluster host is the same shape at a narrower mask:
`to_cidrs = ["192.168.0.20/32"]`.

See `../README.md` for the namespace layout and `.clinedocs/calico-netpols.md` for
the tier rules that decide whether any of this traffic survives `calico-system`.
