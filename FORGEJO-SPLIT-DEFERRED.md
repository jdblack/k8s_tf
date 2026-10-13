# Forgejo core/mantle split — DEFERRED

Things deliberately NOT in this change. Each has a "why" and a "when".

## Parked — normal/ongoing backup policy (SEPARATE topic)

These concern the **ongoing** backup machinery, **not** this migration (whose backups are DR-only — D9).
Parked as a user todo: see `todo-backup-policy` in memory.

- **DEF-1 · Longhorn off-box backup target is DOWN.**
  `longhorn-backup` VolumeSnapshotClass fails with `backup target default is not available`.
  Impact: **no** Longhorn off-box backups at all — Velero is the only off-box path.
  Action: fix the Longhorn backup target (BSL/bucket/creds); verify with a test snapshot.
  When: before trusting Longhorn for anything; independent of this split.
  **⚠️ Pass 17 (E17-3): this is LOAD-BEARING for a greenfield rebuild, not cosmetic** — see DEF-14.

- **DEF-2 · `forgejo-data` Velero schedule first run.**
  Schedule created 2026-10-12T07:38Z; the first `0 3 * * *` tick was **2026-10-13T03:00Z**.
  **⚠️ Pass 18 (H18-5): the doc's "not yet reached" is STALE — that tick is now in the past.**
  Action: **confirm the tick actually produced a backup** (and alert if it did not); a schedule that exists
  but never fires is the failure this item was meant to catch.
  When: now.

- **DEF-3 · `forgejo-data` PVC is only ~18h old.**
  Worth understanding *why* it was recreated (a prior redeploy?). Not blocking.

- **DEF-12 · No app-native backup exists.** No scheduled `forgejo dump` + bucket sync; add a CronJob for the
  pair (git+DB+config, and the S3 blobs) — app-native beats the Velero-only story.
  **⚠️ Pass 17 (E17-3): LOAD-BEARING for a rebuild — see DEF-14.**
- **DEF-13 · Only ONE Velero BSL** (`default`, in-cluster SeaweedFS), so even Velero shares a failure domain.
  A second, off-site BSL (AWS S3 — the cluster already has Route53 creds) would make it genuinely redundant.
  **⚠️ Pass 17 (E17-3): LOAD-BEARING** — the only backup shares a failure domain with the cluster it would
  have to rebuild.

## Follow-ups on this change

- **DEF-4 · Forgejo provider registration-token endpoint is deprecated.** The swagger marks
  `GET /api/v1/admin/actions/runners/registration-token` deprecated as of Forgejo 15; the deployed image
  is **16.0.5-rootless** and it **still works** (verified).
  Action: migrate to `POST /admin/actions/runners` when it stops working (note: not idempotent).
  When: on Forgejo upgrade past 16.

- **DEF-5 · Actions cache is ephemeral.**
  `HOME=/data`, cache at `/data/.cache/actcache`, on an `emptyDir` → wiped on pod restart.
  Action: mount a small PVC + set `cache.dir` if cold caches start hurting.
  When: when builds feel slow.

- **DEF-6 · Robot secret placement.**
  Repo-level secrets for `jblack/*` repos. If CI grows, consider an org + org-level secret.
  When: when a Forgejo org owns the publishing repos.

## Housekeeping

- **DEF-8 · `blueprints.secrets` auto-discovery.** authentik's label-based ConfigMap/Secret discovery was
  unverified; we use the explicit list. Revisit if we ever want blueprint delivery without a chart update.
- **DEF-9 · Other apps' OIDC still uses the provider** and stays in `mantle`. Only Forgejo moves to a
  blueprint (because only Forgejo's instance moves to core). If more instances move to core, consider
  generalising `oidc_blueprint`.

*(DEF-7 — a `.tmp/` housekeeping item — was dropped as dead; the gap is harmless.)*

## DR follow-ups (greenfield optionality is a tenet)

- **DEF-10 · Greenfield audit.** Q10 established that greenfield rebuilds must stay possible. Audit the
  whole repo for **same-stack create-then-read** patterns (a `data` source or provider config reading an
  object a module in the *same* stack creates) — the only one found so far is
  `data.external.forgejo_runner_token`, which this change fixes. Anything else found becomes its own task.
  **⚠️ Pass 19 (L19-1): DONE — and the "only one" claim is FALSE, though harmless.** The sweep (21 `data`
  blocks, 6 provider blocks; `terraform_remote_state` = **zero**) confirmed `forgejo_runner_token` is the
  only *plan-time, same-stack, greenfield-fatal* case, and the split **does** fix it (the creator moves to
  `core`). But **three more same-stack create→reads exist**:
  `modules/auth/authentik/ldap_outpost/outpost.tf:1` and `proxy_outpost/main.tf:25` (a `data.authentik_user`
  reading the SA the same module creates — deferred because it keys off the unknown `outpost.id`), and
  `modules/devops/argo/core/argo-cd/outputs.tf:1` (reads a Secret the same module writes — deferred by an
  explicit `depends_on`). All **HARMLESS** (the read is deferred to apply), so DEF-10's *spirit* holds.
  **The genuinely missed danger is the PLANNED one:** D3's `data.authentik_group` in `mantle` is a
  cross-stack create→read of an **asynchronous** producer (the authentik worker applies the blueprint on
  start-up or the 60-min scan), so a cold `plan mantle` can beat the worker and fail. T6.3c is a *human*
  gate; a greenfield rebuild needs a real convergence/retry story before Q10's tenet is honest. **NOT
  fixed — racy.**
- **DEF-11 · Prove greenfield afterwards.** Once the split lands, validate DR by a from-scratch
  `plan` (or a scratch cluster) of `core` then `mantle` with no staging/retries required.

- **DEF-14 · There is no RESTORE path, and no restore has ever been tested. ← the real DR gap.**
  **Pass 17 (E17-3): the plan optimises the *plan* and hand-waves the *data*.** T6.0 *takes* three backups
  and stops; nothing says how to put them back, in what order, or how to prove it worked. And Forgejo is
  stateful (SQLite DB + git repos on the PVC, blobs in the SeaweedFS bucket).
  - **Ordering matters:** DB/PVC first, then the Forgejo pod, then OIDC — a pod that starts before its DB
    exists has no `login_source` row and no admin user.
  - **Rotation vs restore:** a restored *old* DB carries the *old* `client_secret` row; the blueprint carries
    the *new* one. That mismatch is **silent** (E17-4) — the login page renders and SSO just fails.
  - **The vault is empty (R16-3), DEF-1/12/13 are load-bearing, and the only backup shares a failure domain
    with the cluster being rebuilt.**
  Action: write + **rehearse** a restore runbook (dump → PVC → pod → OIDC check) and make DEF-1/12/13
  prerequisites, not follow-ups.
  When: **before** this migration is relied upon as DR cover.

*(Ongoing-backup items DEF-12/DEF-13 were moved up to the parked section — they're a separate topic.)*
