# Forgejo core/mantle split — DEFERRED

Things deliberately NOT in this change. Each has a "why" and a "when".

## Parked — normal/ongoing backup policy (SEPARATE topic)

These concern the **ongoing** backup machinery, **not** this migration (whose backups are DR-only — D9).
Parked as a user todo: see `todo-backup-policy` in memory.

- **D-1 · Longhorn off-box backup target is DOWN.**
  `longhorn-backup` VolumeSnapshotClass fails with `backup target default is not available`.
  Impact: **no** Longhorn off-box backups at all — Velero is the only off-box path.
  Action: fix the Longhorn backup target (BSL/bucket/creds); verify with a test snapshot.
  When: before trusting Longhorn for anything; independent of this split.

- **D-2 · `forgejo-data` Velero schedule has never fired.**
  Schedule created 2026-10-12T07:38Z; first `0 3 * * *` run not yet reached.
  Action: confirm a backup appears after the next 03:00Z tick; alert if missing.
  When: next day after the split.

- **D-3 · `forgejo-data` PVC is only ~18h old.**
  Worth understanding *why* it was recreated (a prior redeploy?). Not blocking.

- **D-12 · No app-native backup exists.** No scheduled `forgejo dump` + bucket sync; add a CronJob for the
  pair (git+DB+config, and the S3 blobs) — app-native beats the Velero-only story.
- **D-13 · Only ONE Velero BSL** (`default`, in-cluster SeaweedFS), so even Velero shares a failure domain.
  A second, off-site BSL (AWS S3 — the cluster already has Route53 creds) would make it genuinely redundant.

## Follow-ups on this change

- **D-4 · Forgejo provider registration-token endpoint is deprecated.** The swagger marks
  `GET /api/v1/admin/actions/runners/registration-token` deprecated as of Forgejo 15; the deployed image
  is **16.0.5-rootless** and it **still works** (verified).
  Action: migrate to `POST /admin/actions/runners` when it stops working (note: not idempotent).
  When: on Forgejo upgrade past 16.

- **D-5 · Actions cache is ephemeral.**
  `HOME=/data`, cache at `/data/.cache/actcache`, on an `emptyDir` → wiped on pod restart.
  Action: mount a small PVC + set `cache.dir` if cold caches start hurting.
  When: when builds feel slow.

- **D-6 · Robot secret placement.**
  Repo-level secrets for `jblack/*` repos. If CI grows, consider an org + org-level secret.
  When: when a Forgejo org owns the publishing repos.

## Housekeeping

- **D-8 · `blueprints.secrets` auto-discovery.** authentik's label-based ConfigMap/Secret discovery was
  unverified; we use the explicit list. Revisit if we ever want blueprint delivery without a chart update.
- **D-9 · Other apps' OIDC still uses the provider** and stays in `mantle`. Only Forgejo moves to a
  blueprint (because only Forgejo's instance moves to core). If more instances move to core, consider
  generalising `oidc_blueprint`.

*(D-7 — a `.tmp/` housekeeping item — was dropped as dead; the gap is harmless.)*

## DR follow-ups (greenfield optionality is a tenet)

- **D-10 · Greenfield audit.** Q10 established that greenfield rebuilds must stay possible. Audit the
  whole repo for **same-stack create-then-read** patterns (a `data` source or provider config reading an
  object a module in the *same* stack creates) — the only one found so far is
  `data.external.forgejo_runner_token`, which this change fixes. Anything else found becomes its own task.
- **D-11 · Prove greenfield afterwards.** Once the split lands, validate DR by a from-scratch
  `plan` (or a scratch cluster) of `core` then `mantle` with no staging/retries required.

*(Ongoing-backup items D-12/D-13 were moved up to the parked section — they're a separate topic.)*
