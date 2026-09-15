# Disaster recovery — the SeaweedFS filer

| | |
|---|---|
| PVC | `data-filer-seaweedfs-filer-0` in `kube-storage` (2Gi) |
| Owner | `StatefulSet/seaweedfs-filer` (1 replica; filer store on the PVC) |
| Tiers | daily + weekly + monthly, retain 2 each |

The filer keeps the **path → file-id namespace** (leveldb2 on this PVC) that
S3 and the FS clients resolve through. The bytes are on the volume servers and
are *not* part of this snapshot: a revert rolls back the catalog, not the data.

Stop the metadata writers first: `deploy/seaweedfs-s3` (every PUT/DELETE goes
through the filer) and, if you can, the workers doing filer-backed chores. Then
`sts/seaweedfs-filer`, revert, and start the filer before the S3 gateway —
otherwise the gateway serves 500s for the length of the recovery. The master and
volume StatefulSets do not need touching; the filer reconnects on start.

What this recovers: a corrupted/lost catalog (files that "disappeared" but whose
bytes are still there, a botched delete, a filer crash that lost its store).
What it costs: files written since the snapshot keep their bytes but lose their
path — the filer's own collection reclaims them eventually, and you cannot
reconstruct the names from the volumes. If the catalog is fine and you want the
*bytes* back, this snapshot is the wrong tool; that is a volume-server problem.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../disaster_recovery.md`](../disaster_recovery.md).
