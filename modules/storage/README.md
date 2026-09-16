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
| `backup.yaml` | **orphaned** — a hand-applied `VolumeSnapshot` for `sonarr-config`; nothing references it (see `../../memory-bank/progress.md`) |

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
