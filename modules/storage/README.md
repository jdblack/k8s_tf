# `storage` — Longhorn and SeaweedFS

The cluster's two stateful backends, plus the snapshot policy for everything
that lands on them. Applied from `stacks/core` (the `seaweedfs_admin` UI is a
`mantle` concern).

| File | What |
|---|---|
| `longhorn.tf` | Longhorn release (pinned `1.12.1`), UI off, `defaultDataLocality: best-effort`, 2 replicas |
| `snapshots.tf` | snapshot-controller + the `longhorn-snapshot` / `longhorn-backup` `VolumeSnapshotClass`es |
| `longhorn_jobs.tf` | **cluster snapshot policy**: three `RecurringJob`s (`snapshot-daily|weekly|monthly`) and the enrolment table that says which PVC gets which tier |
| `snapshot_labeler.tf` | writes the recurring-job group labels onto the Longhorn **Volume** CRs — the only writer of those labels in the repo |
| `seaweedfs/` | SeaweedFS helm release, CSI driver, master/S3 listeners, Grafana dashboard |
| `seaweedfs_admin/` | the `weed` admin UI, authentik-gated (called from `stacks/mantle`) |
| `namespace.tf` | the `kube-storage` namespace |
| `egress.tf` | **egress policy for the whole namespace**: the closed floor + three API exceptions (see below) |
| `ingress.tf` | **ingress policy for the whole namespace**: self + the node addresses + the private gateway's data plane on the three route ports + Prometheus on `:9327` (see below) |
| `longhorn_netpols.tf` | **the one ingress door into `longhorn-system`**: Prometheus → `longhorn-manager:9500`, additive over the chart's six (see below) |
| `backup.yaml` | **orphaned** — a hand-applied `VolumeSnapshot` for `sonarr-config`; nothing references it (see `../../memory-bank/progress.md`) |

## Egress: the namespace is closed, four policies (2026-09-17)

`kube-storage` is the first namespace whose profile *is* the closed floor — own namespace + DNS, no
internet, no LAN, no other namespace — because that is what its traffic actually is. Measured over a
30-day Whisker window: 39 flows, all of them SeaweedFS-internal (`filer`/`volume`/`worker`/`csi-mount`
→ `seaweedfs-volume:8080|:18080`, `→ seaweedfs-master:19333`, `→ seaweedfs-filer:18888`) or DNS to
coredns, plus the outpost's one cross-namespace dial. The four calls in `egress.tf`:

| Policy | Selects | Adds |
|---|---|---|
| `kube-storage-baseline-egress` | `podSelector: {}` — all 28 pods | nothing (self + DNS only) |
| `seaweedfs-csi-controller-egress` | `app=seaweedfs-csi-controller` | the API server (leader-election Leases + watches) |
| `seaweedfs-csi-node-egress` | `app=seaweedfs-csi-node` | the API server (`driver-registrar` writes CRDs + events) |
| `snapshot-controller-egress` | `app.kubernetes.io/name=snapshot-controller` | the API server (VolumeSnapshot reconciliation) |

plus `seaweedfs_admin/egress.tf` in `stacks/mantle` for the outpost → `kube-auth` `:9000` peer. The
blunt version of why this shape is safe here: nothing in the namespace fetches anything off-cluster
at runtime — images are the kubelet's traffic — and the three API grants come from the sidecars' own
RBAC rather than from a flow log, which cannot see watches. What RBAC is *not*: the chart also binds
a `pods` CRUD role to the SA master/volume/filer run as, and no pod in the namespace holds a socket
to the apiserver — the role is shipped, not used. Full reasoning in `egress.tf`.

**Verified on apply:** all 28 pods Running/Ready; `plan` back to `No changes` in both stacks; a fresh
`seaweedfs-csi` PVC bound and round-tripped a file; a `longhorn-snapshot` VolumeSnapshot reached
`ReadyToUse` (proving `snapshot-controller`); the CSI node pod restarted clean with
`PluginRegistered:true` (proving the registrar grant); `/media` (8.5T RWX on `seaweedfs-filer:8888`)
still lists from sonarr; SSO on `admin.seaweedfs.<domain>` still returns 302; and the 30-minute flow
window after the change held 66 records with **zero Deny**.

## Ingress into `longhorn-system`: one additive door (2026-09-17)

The Longhorn chart ships its own ingress policy set for `networkPolicies.restrictInternalTraffic`
(default `true`), so this namespace was already default-deny inbound on the day it was deployed —
six policies, all Ingress, no egress. That set is an in-namespace mesh plus a webhook allow
(`from: any` on `:9501`/`:9502`); `longhorn-manager` admits in-namespace peers on **every port** and
nothing else, which is why `up{job="longhorn-backend"}` read 1 on all six pods while the flow log had
never seen a *successful* Prometheus scrape: the sample was riding a connection opened before the
chart policies landed on 2026-09-01, and **a connection that never ends is never emitted into the
flow log**. The break was invisible until Prometheus restarted.

Calico only **unions** policies, so this file can open a door and never close one — it exists for the
door, not as a fence:

| Policy | Selects | Adds |
|---|---|---|
| `longhorn-manager-metrics-ingress` | `app=longhorn-manager` | `monitoring` / `app.kubernetes.io/name=prometheus` → TCP 9500, and nothing else (`allow_namespace` and `allow_nodes` both off) |

Three traps recorded here, because each one costs a debugging cycle:

- **Three policies union onto the manager pod** (`longhorn-manager`, plus the webhook and
  recovery-backend policies, by three different labels on the same pod) — that is what keeps the
  kubelet's `/v1/healthz` probe on `:9502` working. Setting `restrictInternalTraffic: false` is
  therefore *not* a fix for anything: it takes the webhook allow with it and every manager pod goes
  `NotReady` with an unqualified deny in place.
- **`allow_k8s_api` reads the `kubernetes` Service and its Endpoints, and this module is
  `depends_on = [module.network]`** — never add a `depends_on` to a firewall call here, or a plan
  with pending network changes dies with `inconsistent final plan`.
- **A port allowed by policy with nothing listening answers `connection refused`, not timeout** — and
  the reverse conflation is worse: a `Service` port that kube-proxy has no rule for *drops*, so
  `curl https://longhorn-admission-webhook:9501` times out while the pod IP on `:9501` refuses. The
  service publishes `9502` only; the `9501` allow is an open, unlistened door. Same read from inside:
  `/proc/net/tcp` on a manager pod listens on 9500, 9502 and 9503.
- **`9502` is TLS, so `curl` without `-k` reports `rc=60` (untrusted cert) on a perfectly reachable
  port** — the handshake got far enough to present a cert, which is why the code is `60` and not `7` or
  `28`; with `-k` the real answer appears (`HTTP/2 200`, `content-length: 0` on `/v1/healthz`, `404` on
  `/`). A plain-`http://` request to the same port returns a Go TLS listener's `400` rather than
  resetting, so a `400` there is also "awake".
- **The data path is fenced too, and this is the check that proves the timeouts are policy rather than
  dead ports:** instance-manager pods listen on 3260 (iSCSI), 6060 (pprof), 8500–8503 (gRPC/proxies) and
  10061–10066, all IPv6-only except 3260 — and from `default` every one of them is a silent timeout
  with a `Deny / EndOfTier / trigger=instance-manager` record. Ports that answer nothing to a *denied*
  source and are *known* to be listening behind the policy is the shape you want.

**Verified on apply:** the policy landed alone (plan `1 to add`), then a forced reconnect — Prometheus
pod deleted, new pod IP — came back with **6/6 targets up** and scrape ages under 30s, and the flow
log attributes them to `longhorn-manager-metrics-ingress` (363 KB out, 14 KB in). Negative controls in
the same window: a pod in `default` times out on 9500 and 9503 and gets http 200 on 9502, and a pod in
`monitoring` that does not carry the `prometheus` label times out too — the grant is pod-scoped, not
namespace-wide.

Not done, on purpose: the egress half (this namespace is the last one with none, and its wildcards are
the `longhorn-driver-deployer` and Job pods, which carry `longhorn.io/job-task` instead of `app`), and
the `:9501`/`:9502` any-source door, which only the chart can narrow and only by this module owning
those policies.

## Snapshot policy in one paragraph

Longhorn joins a `RecurringJob` to a volume by a **group label on the Volume
CR** (`RecurringJob.spec` has `groups`; there is no volume list). So the labels
are cluster policy, not app config: they are written here, on volumes, and no
PVC in this repo sets `recurring-job.longhorn.io/*` — a PVC that does **replaces**
the volume's whole group set instead of merging, silently de-enrolling it.
Three jobs, uniform retention (`retain: 2` per tier), UTC cron, and **never a
`default` group**, because Longhorn stamps every new unlabelled volume into
`default` and a `default`-group job would sweep all the volumes nobody meant to
protect. Enrolling a new volume is one line in `snapshot_groups`.

What is actually protected, what the tiers mean, how to audit the join, and the
verified recovery procedure (revert needs maintenance mode, and the manager API
is in-cluster only) — [`disaster_recovery.md`](disaster_recovery.md).

## Conventions

- Longhorn/snapshot CRs go through `kubectl_manifest`, not `kubernetes_manifest`:
  their CRDs are installed by the Helm releases in the same apply run, and
  `kubernetes_manifest` needs the CRD at plan time ([`snapshots.tf`](snapshots.tf)
  spells this out).
- Anything the CSI provisioner creates (the Volume CR behind a PVC) is reached
  with `kubectl` in a `local-exec`, [the same way
  `modules/network/api_gateway_config.tf`](../network/api_gateway_config.tf)
  installs the Gateway API CRDs. `terraform_data` re-runs only when its
  `triggers_replace` changes, so a labeler re-run is an explicit `-replace`.
