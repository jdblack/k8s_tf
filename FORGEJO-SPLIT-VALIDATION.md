# Forgejo core/mantle split — POST-WORK VALIDATION

Run **after** Phase 6 applies, in order. Any FAIL = investigate before declaring done.

## A. Terraform converged

- [ ] V-A1 `cd stacks/core && tofu plan` → **No changes**
- [ ] V-A2 `cd stacks/mantle && tofu plan` → **No changes**
- [ ] V-A3 `stacks/core` state now owns `module.forgejo.*` (namespace, helm, storage, expose, ingress,
      egress*, backup) — `tofu state list | grep -E '^module\.forgejo(\.|$)'`.
      **⚠️ Pass 18 (I18-1): the old pattern `grep '^module\.forgejo'` is a PREFIX match, so it ALSO matches
      `module.forgejo_runner` — it could never pass or fail correctly.** The `(\.|$)` bound is what makes it
      exact.
- [ ] V-A4 `stacks/mantle` state owns **no `module.forgejo`** at all —
      `tofu state list | grep -E '^module\.forgejo(\.|$)'` returns **nothing** (the CI module is named
      `module.forgejo_setup`, and `module.forgejo_runner` legitimately remains).
- [ ] V-A5 No resource in either state is `module.forgejo.module.oidc.*` anymore (forgotten, D4)
- [ ] V-A6 `git status` clean; `tofu fmt -check` clean
- [ ] V-A7 The moved `kubernetes_manifest` resources (`expose`/`listener_set`) show **no diff**
      (they re-read live objects; a diff means the move didn't land clean)

## B. Forgejo instance healthy (no data loss)

- [ ] V-B1 `kubectl -n devops-forgejo get pod` → Forgejo `1/1 Running`, **RESTARTS low**, same PVC
- [ ] V-B2 PVC `forgejo-data` is the **same volume** (`kubectl get pvc forgejo-data -o jsonpath='{.spec.volumeName}'`)
      — matches pre-change value `pvc-1c01d7ea-f753-4a61-ae70-44a4ad486c3d`
- [ ] V-B3 Data intact: `kubectl -n devops-forgejo exec deploy/forgejo -c forgejo -- du -sh /data` ≈ 7.8G
- [ ] V-B4 DB intact: `forgejo.db` present; repo count matches pre-change
      (via API: `GET /api/v1/repos/search?limit=1` → `.ok`, or count `git` dirs)
- [ ] V-B5 A known repo clones and a known commit is present (spot check)
- [ ] V-B6 **Forgejo web UI loads** at `https://git.<domain>` (login page renders)
- [ ] V-B7 SeaweedFS bucket intact: LFS/attachments still resolve (spot check an avatar/attachment)
- [ ] V-B8 **`s3_user` creds did NOT rotate** — the SeaweedFS access/secret keys are unchanged
      (`kubectl -n devops-forgejo get secret forgejo-s3 -o jsonpath='{.data}'` vs pre-change);
      a rotation would break Forgejo→S3
- [ ] V-B9 **Velero schedule survived** the move: `kubectl -n kube-backup get schedule forgejo-data` exists
      with the same spec, and still references namespace `devops-forgejo`

## C. OIDC works (was the risky bit)

- [ ] V-C1 The authentik blueprint applied: `kubectl -n kube-auth logs deploy/authentik-worker | grep -i blueprint`
      shows no error for the Forgejo blueprint
- [ ] V-C2 Application `forgejo` exists in authentik (UI or API) with the OAuth2 provider attached
- [ ] V-C3 Objects **adopted**, UUIDs unchanged (D4 goal) — compare against the baseline in
      `FORGEJO-SPLIT.md` §10:
      `forgejo-admin` = `e99a0ce2-3e14-4921-9f35-f006938097c1`,
      `forgejo-user` = `0e04476d-b7c6-46e7-98a4-f0035035a183`,
      signing key pair = `4f322590-d2d4-48c8-9c4b-0f89ffe49120`,
      oauth2 provider pk = `57`, application slug = `forgejo`.
      A **changed** group UUID = the blueprint recreated instead of adopting → STOP, the umbrella
      `admin`/`user` nesting in `mantle` is at risk.
- [ ] V-C4 Umbrella groups (check **authentik directly**, not a plan diff): group `admin` still lists
      **`forgejo-admin`** among its parents, and `user` lists **`forgejo-user`** (API/UI). Note V-A2's
      "No changes" does **not** prove this — `data.authentik_group` would re-read a changed id silently.
- [ ] V-C5 **Log in to Forgejo via SSO** end to end (fresh incognito), land authenticated
- [ ] V-C6 An admin still gets admin (group claim maps `forgejo-admin` → admin)
- [ ] V-C7 **Break-glass local admin** still works (password from `forgejo-admin` Secret)
- [ ] V-C8 **both** redirect URIs present: the callback
      `https://git.<domain>/user/oauth2/authentik/callback` **and** the site root `https://git.<domain>`
      (the old `extra_redirect_uris`). Dropping the second breaks post-logout return.
- [ ] V-B10 **Restore drill (M6).** Restore `dump/` **and** `s3/` into a scratch namespace and confirm a
      repo clones and the DB loads. Under "data is sacred" (D8), an **untested** backup is a wish — this is
      the single highest-value check in the file.
- [ ] V-C9 **Provider fidelity (R8):** the adopted provider's `grant_types`, `access_token_validity`,
      `refresh_token_validity`, **`redirect_uris`** (the model field — *not* `allowed_redirect_uris`), and
      `property_mappings` match the pre-change values in `oidc_provider/auth.tf` (a missing scope = broken
      role mapping; empty `grant_types` = every flow rejected)
- [ ] V-C10 **Cluster-wide SSO still healthy (R12):** the authentik worker rolled out cleanly and
      **another** app (harbor / argo / grafana) still logs in — the blueprint change touched the shared
      authentik worker

- [ ] V-C11 **Non-OIDC auth surfaces still work (K19-1).** OIDC is **NOT** the only auth surface: `git clone`
      over **SSH** on the LoadBalancer VIP (SSH keys — no OIDC, TLS or gateway involved) and the
      **`breakglass` basic-auth/API** credential (`curl -u breakglass:<pw>`) must both still work after the
      split. The gateway is a dumb TLS terminator, so there is no forward-auth layer to test.

## D. Runner still fine

- [ ] V-D1 `kubectl -n devops-forgejo-runner get pod` → `2/2 Running`, on a `k8sn*` node (not master)
- [ ] V-D2 Forgejo shows the runner `idle`; labels `[ubuntu-latest, docker]`
- [ ] V-D3 Runner pod mounts **no** `kube-api-access-*` volume (hardening intact)
- [ ] V-D4 Submit a trivial workflow and confirm it runs green (real end-to-end)

## E. The actual goal — Harbor push path  ✅ ALL GREEN 2026-10-13

Delivered and verified live: `.forgejo/workflows/publish-dev.yml` in ellmephant, run 5 (`publish`, event
`push` to `dev`), **status `success`**.

- [x] V-E1 `harbor_robot_account.forgejo` exists in Harbor: **`robot$library+forgejo`** (project `library`).
      Read from state (the robot-list API does not surface project robots — a Harbor quirk):
      `full_name = "robot$library+forgejo"`, `robot_id = "2"`, `level = "project"`.
- [x] V-E2 **No expiry** — state `duration = -1`.
- [x] V-E3 Permissions exactly: `repository: pull`, `repository: push`, `tag: create`, `tag: list` — and
      **no delete**, verified as the full permission set in state.
- [x] V-E4 Both secrets present on `jblack/ellmephant` — `HARBOR_USER` + `HARBOR_TOKEN`
      (`GET .../actions/secrets`, both `created_at 2026-10-13T08:04:42Z`).
- [x] V-E5 **End-to-end:** run 5 logged in (`Login Succeeded`), built, and pushed
      `harbor.vn.linuxguru.net/library/ellmephant:sha-ec9f28b` **and** `:edge`
      (digest `sha256:1c0c6114…`). Confirmed in Harbor: one artifact, tags `["edge","sha-ec9f28b"]`,
      `push_time 2026-10-13T08:10:53Z`.
- [x] V-E6 Anonymous pull works for `library` (public): got a token from `/service/token` with **no
      credentials** and listed the tags successfully.

## F. Provider plumbing

- [ ] V-F1 `stacks/mantle` `provider "forgejo"` authenticates (plan succeeds with data sources)
- [ ] V-F2 `data.forgejo_repository.*` resolves for every repo in `forgejo_registry_repos`
- [ ] V-F3 No new chicken-and-egg: an `apply` of `core` alone, then `mantle` alone, both plan clean

## G. Rollback readiness check (do NOT delete yet)

- [ ] V-G1 **D9 vault populated** — ✅ as of Pass 22 it is (`dump/` 8.34 GB gzip-verified, `s3/`, `tfstate/`),
      but still verify the **fresh T6.0 set**, not this pre-split one. *(History: Pass 18/H18-3 caught that
      this check was **false as written** — it asserted a populated vault that was in fact empty, directly
      contradicting the checklist. **An unpopulated vault must FAIL this gate, not pass it.**)*
- [ ] V-G2 Velero backup `forgejo-pre-split` still `Completed` and within TTL
- [ ] V-G3 The pre-change state backups are retrievable for at least a few days after cutover

## H. Sign-off

- [ ] V-H1 All gates above pass
- [ ] V-H2 Deferred items re-filed (**DEF-1…DEF-14**; DEF-1/DEF-2/DEF-3/DEF-12/DEF-13 are the parked
      backup-policy topic, and DEF-1/12/13/14 are now marked **load-bearing**)
- [ ] V-H3 Memory updated
- [ ] V-H4 Commit + push
