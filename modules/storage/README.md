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
| `egress.tf` | **egress policy for the whole namespace**: the closed floor + three API exceptions (see below) |
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
