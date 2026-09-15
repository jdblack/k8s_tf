# Disaster recovery — Prowlarr

| | |
|---|---|
| PVC | `prowlarr-config` in `media` (`/config`) |
| Owner | `Deployment/prowlarr` (1 replica) |
| Tiers | monthly, retain 2 |

`prowlarr.db` + `config.xml`: the indexer list with its **credentials**, caps and
priorities, plus the connections to Sonarr/Radarr. This is the one piece of the
arr stack that is mostly hand-built credentials rather than derivable state,
which is why it gets a monthly at all while `sonarr-config`/`radarr-config` do
not.

Scale `deploy/prowlarr` to 0 before the revert: SQLite is mid-write constantly
while the UI and the sync tasks run. After the revert, scale back and check
`Settings → Indexers` — anything added since the snapshot is gone (re-add the
API keys), and anything *removed* since it is back.

Prowlarr is the source of truth the other apps sync from, so your recovery is
not done when the UI loads: the arr apps still hold whatever set they last
synced. Re-run `Settings → Apps → Sync App Indexers` (or a full sync per app) so
Sonarr/Radarr match the recovered Prowlarr, otherwise indexers deleted in the
meantime keep being used.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../../storage/disaster_recovery.md`](../../storage/disaster_recovery.md).
