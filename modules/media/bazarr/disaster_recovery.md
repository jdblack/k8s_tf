# Disaster recovery — Bazarr

| | |
|---|---|
| PVC | `bazarr-config` in `media` (`/config`) |
| Owner | `Deployment/bazarr` (1 replica, also mounts the shared `movies-archive` volume) |
| Tiers | monthly, retain 2 |

`bazarr.db` + `config/config.yaml`: language profiles per series/movie, subtitle
provider credentials, the Sonarr/Radarr connections, and the history of what was
downloaded. The *subtitle files themselves* live on the archive volume with the
media — untouched by a revert.

Scale `deploy/bazarr` to 0 first (SQLite is written by the scanner and the
scheduler), revert, scale back to 1. Then reconcile, because the reverted history
disagrees with the disk: run a full scan (`Tasks → Scan Series` / `Scan Movies`)
so Bazarr re-derives what subtitles exist instead of trusting its rolled-back
table. Providers and the language profiles are the part worth restoring by hand —
everything else re-derives.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../../storage/disaster_recovery.md`](../../storage/disaster_recovery.md).
