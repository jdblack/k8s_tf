# Disaster recovery — vaultwarden

| | |
|---|---|
| PVC | `vaultwarden-data` in `vaultwarden` (`/data`) |
| Owner | `Deployment/vaultwarden` (`strategy: Recreate`, 1 replica) |
| Tiers | daily + weekly + monthly, retain 2 each |

A revert rolls `/data` — SQLite `db.sqlite3`, `attachments/` (and the
attachments themselves, which exist nowhere else), `sends/`, `rsa_key*` — back
to the snapshot instant. The volume is RWO, so the pod must stop first
(`kubectl -n vaultwarden scale deploy/vaultwarden --replicas=0`), which is
exactly why the module pins `strategy: Recreate`.

**The clients are the primary copy.** Every Bitwarden client holds a full local
vault, and `/admin` is disabled by design (no `ADMIN_TOKEN`), so this server is
a sync point rather than the last line of defence. What only exists here:
attachments, `sends`, and organisation/collection state. Before a *deliberate*
downgrade, have clients export.

After the revert, start the pod and check clients sync. A reverted DB can be
older than a client's last local change, and the next client sync wins — that is
normal for this app, not a failed recovery.

**Legacy restore points:** two snapshots named `vaultwar-<uuid>` remain from the
retired per-app job (14th and 15th, 03:00 UTC). No job prunes them — Longhorn
retains per-job, and foreign snapshots survive (verified) — so they are extra
insurance until the new `snapshot-*` runs start landing. Delete them by hand
(`snapshotDelete`) once the vault has a new restore point; they are the only
pre-migration points that exist.

Mechanics, maintenance mode and the in-cluster-only manager API:
[`../storage/disaster_recovery.md`](../storage/disaster_recovery.md).
