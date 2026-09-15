# Disaster recovery — the Harbor database

| | |
|---|---|
| PVC | `database-data-harbor-database-0` in `devops-harbor` |
| Owner | `StatefulSet/harbor-database` (postgresql subchart, 1 replica) |
| Tiers | weekly + monthly, retain 2 each |

Harbor's metadata: projects, robot accounts, users, labels, retention and scan
policies — and the `repository` table that maps image names to blobs in the
registry. Not covered, on purpose: the registry blobs themselves (re-pushable
from the build machines) and `harbor-redis-0` (cache/job queue — scratch).

Stop order: `harbor-core`, `harbor-jobservice` and `harbor-registry` all talk to
this database. Scale those three to 0 (or accept 500s from the UI while you
work), then `sts/harbor-database`, revert, then bring them back and let postgres
finish its own recovery before Harbor starts serving.

A **stale** `repository` table is worse than a missing one: blobs pushed since
the snapshot still exist in the registry but have no row pointing at them, so the
UI shows a smaller catalog than the disk holds. Re-push those images, or prune
the registry. Robot accounts and project membership roll back with everything
else — build pipelines using them need their credentials re-checked.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../../storage/disaster_recovery.md`](../../storage/disaster_recovery.md).
