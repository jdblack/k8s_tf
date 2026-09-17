# Disaster recovery — Longhorn snapshots

**This is recovery, not backup.** Every snapshot here lives on the same disks as
the volume it protects, so it covers *logical* damage — a bad upgrade, a dropped
table, a wiped config, an app that wrote garbage over its own data — and it
covers it only while the damage is noticed inside the retention window. It
covers **nothing** about losing a node, a disk pool, the cluster, or the house.
There is no `backupTarget` in this cluster: no snapshot has ever left it. The
offsite gap is tracked in [`../../memory-bank/progress.md`](../../memory-bank/progress.md).

Who owns what: the jobs and the enrolment table live in
[`longhorn_jobs.tf`](longhorn_jobs.tf), the labels that join them to volumes in
[`snapshot_labeler.tf`](snapshot_labeler.tf). This file is the *operator's* side:
what is protected, how to check it, and how to actually put data back.

## What is covered

| PVC | ns | Tiers | Retain | Why this volume |
|---|---|---|---|---|
| `data-authentik-postgresql-0` | `kube-auth` | daily+weekly+monthly | 2/2/2 | identity + every SSO binding; a rebuild means re-creating users, groups and OIDC clients by hand |
| `data-filer-seaweedfs-filer-0` | `kube-storage` | daily+weekly+monthly | 2/2/2 | the file catalog — the S3 data is fine, the map to it is not |
| `vaultwarden-data` | `vaultwarden` | daily+weekly+monthly | 2/2/2 | the vault, and the attachment blobs that exist nowhere else (see the caveat below) |
| `database-data-harbor-database-0` | `devops-harbor` | weekly+monthly | 2/2 | images are re-pushable, projects/robot accounts/scan policy are not |
| `prometheus-grafana` | `monitoring` | weekly+monthly | 2/2 | dashboards and datasources are TF/ConfigMap-owned; users, annotations and API keys are not |
| `admin-data-seaweedfs-admin-0` | `kube-storage` | monthly | 2 | hand-edited `weed` admin config; minutes to redo once you remember it |
| `bazarr-config` | `media` | monthly | 2 | per-language subtitle profiles: the fiddly part of the media stack |
| `prowlarr-config` | `media` | monthly | 2 | the indexer list (credentials, caps, priorities) — the source of truth for the other arr apps |

Retention is **2 snapshots per tier, per volume, uniformly**. Two consequences
worth internalising: Longhorn prunes only once the count is *exceeded*, and it
**skips a run outright when the volume head has not changed** — so a "daily" is
the last two *data-changing* days, not the last two calendar days (verified: a
2-minute job with 5 executions produced 1 snapshot on a volume nobody was
writing to). Tiers are uniform on purpose: tiering by app encoded sentiment, not
recoverability. `vaultwarden` used to be special with a 7-deep nightly job, but
every Bitwarden client holds a full copy of the vault — it is arguably the
volume *least* dependent on this machinery. Uniform also means one rule to
remember and one rule to audit.

### Deliberately not snapshotted

`harbor-redis-0` (cache/queue — the database is the state), `harbor-jobservice`
(scratch), `seaweedfs-master-0` (topology; volumes re-register),
`qbittorrent-data` (the torrent list is re-addable from the archive volume),
`plex-pms-config-plex-media-server-0` (metadata re-scans from the library paths;
it is a VCT-driven volume — see `memory-bank/progress.md`). `sonarr-config`
and `radarr-config` are the same *shape* of volume as `prowlarr-config` /
`bazarr-config` and are only skipped on judgement — that asymmetry is not
principled. Enrolment is a 3-line change plus an apply (`snapshot_groups` in
`longhorn_jobs.tf`), so tightening this is cheap.

## How the join works (and the three ways it breaks silently)

Longhorn matches a `RecurringJob` to a volume by **group label on the Volume CR**
— `RecurringJob.spec` has `groups`, there is no volume list. Everything below
follows from that:

1. **The labels are written by Terraform, on volumes, and nowhere else.**
   `snapshot_labeler.tf` resolves each enrolled PVC's `spec.volumeName` and
   labels that Volume CR. No PVC in this repo carries `recurring-job.longhorn.io/*`
   (vaultwarden did, until 2026-09-16). Never add one: a PVC with
   `recurring-job.longhorn.io/source: enabled` **replaces** the volume's entire
   group set rather than merging into it, so a hand-labelled PVC silently
   de-enrols the volume from every tier. Not theoretical: during the migration
   the vaultwarden volume went `daily,monthly,weekly` back to `vaultwarden`
   within seconds of a labeler run, because its PVC was still the label source.
2. **A job must never list `default` in `spec.groups`.** Longhorn stamps every
   freshly provisioned, unlabelled volume with
   `recurring-job-group.longhorn.io/default: enabled` (verified on a brand-new
   1Gi volume), so a `default` group would silently sweep all 7 skipped volumes
   into the job's retention policy. The audit fails if any job does this.
3. **Deleting a job or a label leaves the volume labelled.** Labels are not
   garbage-collected with the job, and a volume that changes tier keeps its old
   group until the labeler runs again. Re-running one labeler is a `-replace` of
   a single address, not a rebuild:
   ```sh
   tofu -chdir=stacks/core apply \
     -replace='module.storage.terraform_data.snapshot_group["vaultwarden/vaultwarden-data"]'
   ```
   The labeler runs from `stacks/core`, which is applied *before* the stacks
   that create the PVCs: on a fresh cluster it warns and skips any PVC that does
   not exist yet. Re-apply `stacks/core` after `mantle`/`apps` have created
   their volumes.

## Coverage audit

Run this after anything touches volumes, jobs or labels. Blocks 3 and 4 must
print nothing.

```sh
# 1. pvc -> groups -> state
kubectl -n longhorn-system get volumes.longhorn.io -o json | jq -r '
  .items[] | [ .status.kubernetesStatus.namespace + "/" + .status.kubernetesStatus.pvcName,
               ([ (.metadata.labels // {}) | to_entries[]
                  | select(.key | startswith("recurring-job-group.longhorn.io/"))
                  | (.key | split("/")[1]) ] | sort | join(",")),
               .status.state ] | @tsv' | sort

# 2. jobs
kubectl -n longhorn-system get recurringjobs.longhorn.io -o json | jq -r '
  .items[] | [ .metadata.name, .spec.cron, (.spec.retain|tostring),
               (.spec.groups|join(",")) ] | @tsv' | sort

# 3. every volume enrolled, and every group it holds is a real job or exactly "skip"
kubectl -n longhorn-system get volumes.longhorn.io -o json > /tmp/v.json
kubectl -n longhorn-system get recurringjobs.longhorn.io -o json > /tmp/j.json
jq -r --slurpfile j /tmp/j.json '
  [ $j[0].items[].spec.groups[] ] as $jobgroups
  | .items[] | [ (.metadata.labels // {}) | to_entries[]
                 | select(.key | startswith("recurring-job-group.longhorn.io/"))
                 | (.key | split("/")[1]) ] as $g
  | select( ($g|length) == 0
            or ($g | map(select(. != "skip" and ($jobgroups | index(.)) == null)) | length) > 0 )
  | "\(.status.kubernetesStatus.namespace)/\(.status.kubernetesStatus.pvcName): groups=\($g|join(","))"' /tmp/v.json

# 4. no job may use the default group
jq -r '.items[] | select(.spec.groups | index("default"))
       | "VIOLATION: \(.metadata.name)"' /tmp/j.json
```

Real output, 2026-09-15 (`temp-fire-test` and `dr-scratch` were the throwaway
verification fixtures, since deleted):

```
devops-harbor/data-harbor-redis-0            skip              attached
devops-harbor/database-data-harbor-database-0 monthly,weekly   attached
devops-harbor/harbor-jobservice              skip              attached
kube-auth/data-authentik-postgresql-0        daily,monthly,weekly attached
kube-storage/admin-data-seaweedfs-admin-0    monthly           attached
kube-storage/data-filer-seaweedfs-filer-0    daily,monthly,weekly attached
kube-storage/data-kube-storage-seaweedfs-master-0 skip         attached
media/bazarr-config                          monthly           attached
media/pms-config-plex-plex-media-server-0    skip              attached
media/prowlarr-config                        monthly           attached
media/qbittorrent-data                       skip              attached
media/radarr-config                          skip              attached
media/sonarr-config                          skip              attached
monitoring/prometheus-grafana                monthly,weekly    attached
vaultwarden/vaultwarden-data                 daily,monthly,weekly attached

snapshot-daily    0 3 * * *    2  daily
snapshot-monthly  0 5 28 * *   2  monthly
snapshot-weekly   0 4 * * 0    2  weekly
```

Note what the labeler also *removes*: no live volume carries `default` any more,
because `snapshot_known_groups` strips it. That is cosmetic and self-healing —
Longhorn only re-adds it to a volume that has no group labels at all, and the
labeler adds before it strips for exactly that reason.

## Recovery: putting a volume back to a snapshot

`snapshotRevert` rolls the volume back **in place**: everything written since the
target snapshot is discarded; the PVC, PV, volume, and the app's mounts all stay
as they are. Snapshots created after the target still appear in the list
afterwards (verified), but do not bet a recovery on them: take a fresh restore
point once you are happy.

**Hard precondition — the volume must have no frontend enabled.** The manager
rejects the call with

```
failed to revert snapshot for volume <pv> with frontend enabled      (http 500)
```

whenever `spec.frontend != "" && !spec.disableFrontend`. Deleting the pod is
**not** enough: a detached CSI volume keeps `spec.frontend: blockdev`, so the
call still fails (verified). You have to enter maintenance mode. In v1.12 that
state is owned by the **attachment ticket**, not by the Volume CR —
`spec.disableFrontend` is derived from the tickets, so a direct patch of the
Volume CR is reverted by the controller within seconds (verified).

The manager API is reachable **only from inside the cluster**: `kubectl
port-forward` fails (the manager binds its pod IP, not localhost) and the
apiserver service-proxy is flaky (it DNATs to all manager pods, and some are
unreachable from the control-plane host). `kubectl exec` into any manager pod
and talk to the ClusterIP:

```sh
NS=media; PVC=bazarr-config                     # <- the volume you are recovering
PV=$(kubectl -n $NS get pvc $PVC -o jsonpath='{.spec.volumeName}')
MGR=$(kubectl -n longhorn-system get pods -l app=longhorn-manager -o jsonpath='{.items[0].metadata.name}')
lh() { kubectl -n longhorn-system exec "$MGR" -c longhorn-manager -- \
         curl -s -w '\nhttp=%{http_code}\n' -X POST \
         "http://longhorn-backend:9500/v1/volumes/$PV?action=$1" \
         -H 'Content-Type: application/json' -d "$2"; }

# 1. stop the app and keep it stopped -- nothing may write during the revert
kubectl -n $NS scale deploy/<app> --replicas=0        # or delete the pod / scale the sts

# 2. list the restore points; pick by `created`, the names are opaque (below).
#    No API at all? The same snapshots are `snapshots.longhorn.io` CRs (see Gaps).
lh snapshotList '{}' | jq -r '.data[]|"\(.created) \(.name)"' | sort

# 3. maintenance mode -- use (a) if a ticket still exists, else (b)
#   (a) the pod's CSI ticket usually lingers after the scale-down:
TICKET=$(kubectl -n longhorn-system get volumeattachments.longhorn.io "$PV" \
           -o jsonpath='{.spec.attachmentTickets}' | jq -r 'keys[0]')
kubectl -n longhorn-system patch volumeattachments.longhorn.io "$PV" --type=merge \
  -p "{\"spec\":{\"attachmentTickets\":{\"$TICKET\":{\"parameters\":{\"disableFrontend\":\"true\"}}}}}"
#   (b) no ticket at all (volume fully detached):
lh attach '{"hostId":"k8sn2","attacherType":"longhorn-api","attachmentID":"dr","disableFrontend":true}'

# 4. confirm: must print `true true`
kubectl -n longhorn-system get volumes.longhorn.io "$PV" \
  -o jsonpath='{.spec.disableFrontend} {.status.frontendDisabled}{"\n"}'

# 5. revert
lh snapshotRevert '{"name":"<snapshot>"}'             # http=200

# 6. leave maintenance mode
#   (a) patch the same ticket's disableFrontend back to "false"
#   (b) lh detach '{"attachmentID":"dr","hostId":"k8sn2"}'

# 7. start the app again, then verify the data before walking away
kubectl -n $NS scale deploy/<app> --replicas=1
```

Notes and traps, all verified:

- `hostId` and `attachmentID` must match between the attach and the detach
  (`"dr"` above). `attacherType: longhorn-api` is the manual attach; the ones
  Longhorn creates for running pods are `csi-attacher`.
- A volume that will not detach usually has a lingering
  `volumeattachments.storage.k8s.io` object (`kubectl get volumeattachments.storage.k8s.io
  | grep $PV`). Deleting it takes the Longhorn ticket with it.
- **Snapshot names carry no tier.** A job-created snapshot is named
  `<job name truncated to 8 chars>-<uuid>`, and all three jobs start with
  `snapshot` — so every tier produces `snapshot-<uuid>`. Identify a restore point
  by creation time (`created` above, or `.metadata.creationTimestamp` on the
  `snapshots.longhorn.io` CR), never by name. Manually created snapshots are the
  ones with `usercreated: true`.
- Cheap insurance before a risky change (an upgrade, a migration): take your own
  restore point first — `lh snapshotCreate '{"name":"pre-revert-20260916"}'`
  (letters, digits, `-` and `_` only). No job prunes it, so delete it yourself
  with `snapshotDelete` when the change proves out.
- Cron is UTC; the box is UTC-7, so **daily 03:00 UTC = 20:00 local**,
  **weekly Sun 04:00 UTC = Sat 21:00 local**, **monthly 28th 05:00 UTC = 27th
  22:00 local**.

## Evidence — what was actually verified (2026-09-15)

On a throwaway 1Gi volume in `dr-scratch` plus a throwaway 2-minute job in a
throwaway group (both deleted afterwards; no production volume was reverted):

| Claim | Result |
|---|---|
| A job joins a volume by Volume-CR label alone | label + `cron: */2` job → `status.executionCount: 1` and a snapshot on the throwaway volume; no PVC label anywhere |
| New volumes start in the `default` group | `recurring-job-group.longhorn.io/default: enabled` present at creation |
| Revert is refused while a workload is attached | http 500, `failed to revert snapshot for volume ... with frontend enabled` |
| Revert is refused while merely *detached* | identical error — `spec.frontend` stays `blockdev` |
| Patching the Volume CR's `disableFrontend` works | **no** — reverted by the controller within seconds |
| Patching the existing CSI ticket's `parameters.disableFrontend` | `spec.disableFrontend=true`, `status.frontendDisabled=true`, no detach needed |
| Revert in maintenance mode | http 200, and after remount the marker file read its **pre-snapshot** value |
| Maintenance mode with no ticket at all | `attach` + `attacherType: longhorn-api` + `disableFrontend: true` → `frontendDisabled=true`; revert http 200; `detach` removed the ticket |
| Snapshot naming | job snapshot `temp-fir-<uuid>` = job name truncated to 8 chars |
| Run skipped when nothing changed | 5 executions, 1 snapshot |
| Manager API reachability | port-forward fails; apiserver service-proxy fails on some DNAT picks (`dial tcp <pod-ip>:9500: i/o timeout`); `kubectl exec` into a manager pod → `http://longhorn-backend:9500` works |

There is **no egress policy on the manager** — `longhorn-system` carries the chart's ingress policies
plus exactly one of ours (`longhorn_netpols.tf`: Prometheus → `:9500`) and no egress policy at all,
which is the half still open. So a helper pod **in this namespace** can reach
`longhorn-backend:9500`, and one anywhere else cannot: measured 2026-09-17, a pod in `default` gets a
silent timeout on `:9500` and `:9503`, and `:9502` answers http 200 because the chart's webhook policy
is `from: any`. `longhorn-manager` itself
ships `/usr/bin/curl`, so `kubectl exec` into it is still the shortest path — and it is the
path the `http://longhorn-backend:9500` result above came from.

## Gaps

- **No offsite copy.** No `backupTarget`: snapshots share the disks and the
  failure domain with their volume. Every claim above is about *logical* damage,
  not about disk, node or house loss. See `../../memory-bank/progress.md`.
- **No rehearsal on real data.** The path was exercised once, by hand, on a
  throwaway volume. Nothing automates a restore test, and the coverage audit
  checks enrolment, not recoverability.
- **vaultwarden** is the server side of the vault only, and its admin panel is
  off by design (no `ADMIN_TOKEN`). Client-side exports remain the portable
  backup; attachments exist only here.
- **Postgres volumes** (authentik, harbor): reverting rolls the data directory
  back and the instance runs its own crash recovery on start. Right tool for
  "the upgrade mangled the schema", wrong tool for anything cross-version.
- **Snapshot CRs are the no-API way in.** Every snapshot is also a
  `snapshots.longhorn.io` CR labelled with its volume, so you can list restore
  points without touching the manager API at all:
  ```sh
  kubectl -n longhorn-system get snapshots.longhorn.io -o json | jq -r '
    .items[] | "\(.metadata.creationTimestamp)  \(.metadata.labels.longhornvolume)  \(.metadata.name)"' | sort
  ```
  (18 CRs cluster-wide on 2026-09-15, matching the enrolled volumes; Longhorn
  does leave CRs behind for deleted volumes in some flows, so check the volume
  still exists before chasing one.)
- **Snapshots carry no tier label.** `RecurringJob.spec.parameters` does not
  surface as snapshot labels in v1.12 — verified with both a bare key
  (`tier: x`) and `labels: "tier=x"`, the snapshot CR came out with no labels.
  Time is the only ordering you get.




