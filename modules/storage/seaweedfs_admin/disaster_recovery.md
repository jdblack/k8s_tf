# Disaster recovery — the SeaweedFS admin UI

| | |
|---|---|
| PVC | `admin-data-seaweedfs-admin-0` in `kube-storage` (`/data`; `/logs` too) |
| Owner | `StatefulSet/seaweedfs-admin` (1 replica, applied from `stacks/mantle`) |
| Tiers | monthly, retain 2 |

`weed admin` keeps its own store on this volume: the registered masters/cluster
and whatever the UI persists about them. It holds no file data and no S3
credentials that only exist here — the UI logs into the cluster's masters — so a
revert is convenience, not survival: the worst case without this snapshot is
re-registering a master URL and clicking a few settings back into place.

Scale `sts/seaweedfs-admin` to 0, revert, scale back. The authentik outpost in
front of it (`seaweedfs-admin-auth`) is a separate Deployment and unaffected;
expect one 502 while the pod restarts. If the UI comes back empty, check which
masters it is pointed at before assuming the revert failed.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../disaster_recovery.md`](../disaster_recovery.md).
