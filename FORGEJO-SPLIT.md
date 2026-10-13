# Forgejo core/mantle split — PLAN

Status: REVIEWED — Q1–Q10 answered, D1–D9 decided; full pass trail in `FORGEJO-SPLIT-REVIEWS.md` · Owner: jblack · Scope: `stacks/core`, `stacks/mantle`, `modules/devops/forgejo*`, `modules/auth/authentik*`

## RESUME HERE (handoff)

- **State:** the plan is fully reviewed and **FROZEN** — **20 passes** (12 self, 2 blind cold reads, 18
  directed subagents across six waves; the loop closed when a wave found the *fold process* itself had become
  the leading defect source). **Nothing has been built or applied.** Every decision (D1–D9) and question
  (Q1–Q10) is settled. Move verified sound (18/18 addresses).
- **⚠️ BLOCKER found in Pass 18 (G18-1) + sharpened in Pass 19 (J19-1):** the live `app.ini` disables the
  Actions repo-unit, **and** no repo has an Actions *unit row* — so T3.8 needs **both**
  `DISABLED_REPO_UNITS = ""` **and** a per-repo `has_actions = true` **write**. Until then the goal's second
  half is inert.
- **⚠️ The DR story is the open sore:** the vault is empty, DEF-1/12/13 are load-bearing, and there is **no
  restore path** (DEF-14). Reviewing the *plan* is done; the *data* side needs its own work.
- **Next step:** freeze these docs and start **Phase 1** — copy-and-trim the live export
  (`.tmp/authentik-export.yaml`) into `modules/auth/authentik/oidc_blueprint/`, then run gate **T1.5**
  (blueprint applies on a scratch name) and **T1.6** (idempotent). **Remember `name = "forgejo"` (T1.3) and
  the `.yaml` Secret key (T1.3).**
- **Before Phase 3:** fix the **Actions blocker (T3.8)** — the goal's second half ships inert otherwise.
- **Open:** `forgejo_registry_repos` (the repo list — **owner-gated**, T3.6/T3.7, blocks V-E4);
  `DEF-1…DEF-14` in `-DEFERRED.md`; the parked normal-backup topic (`todo-backup-policy` in memory).
- **Where things live:** move script `.tmp/forgejo-split-move.py` and export `.tmp/authentik-export.yaml`
  are **gitignored but kept**; surgery `state` scratch in `.tmp/backups/`; DR vault
  `/Users/jblack/backups/forgejo/`.
- **Do this first:** `tofu validate` both stacks, and re-read **Phase 3's triage** (T3.1) before touching a
  single `oidc_*` symbol — that step is where every real trap lives.

## 1. Goal

Move the Forgejo **instance** (helm release, namespace, storage, exposure, backup) out of the `mantle`
stack and into `core`, re-implement Forgejo's authentik OIDC as an authentik **blueprint** (so no
authentik terraform provider is needed in core), and **add** the **forgejo terraform provider** +
Harbor push robot + Actions secrets in `mantle` — **none of that exists yet** (see §3). Constraint:
**zero Forgejo data loss**.

**PRIORITY (owner, explicit): short service disruption is acceptable; data loss is not.** So the plan
optimises for **exactly one thing — zero data loss**. Every availability concern (pod restarts, SSO gaps,
worker rolls, the OIDC window, downtime during a restore) is a **non-issue**, and the gates say so (D8).

## 2. Why (root causes)

1. **Provider bootstrap.** A terraform provider used by a stack must target something that already
   exists. Harbor and Argo follow the house pattern — *instance in `core`, provider + setup in
   `mantle`*. Forgejo is the lone exception: its instance is in `mantle`.
2. **OIDC must co-reside with the helm release.** Forgejo's OIDC client must be known when
   `helm_release` applies — the chart feeds it to the init container, which re-syncs the DB `login_source`
   row on **every pod start** (it is **not** "baked into `app.ini`"; Pass 20, O20-7). Whatever creates those
   creds must live with the helm release.
3. **The authentik terraform provider cannot run in `core`.** Its token is
   `random_password.terraform_key.result`, created *by core itself* and **unknown at plan time**.
   Providers must be configured at plan time, so a greenfield `apply` of core would fail. That is
   precisely why every provider-based OIDC today lives in `mantle` (which applies after core).
4. **Resolution.** Do Forgejo's OIDC with an authentik **blueprint** — applied by authentik itself,
   needing no terraform provider and no plan-time credential. Then the whole instance can live in
   `core`, and `mantle` gets a clean forgejo provider.
5. **DR tenet — Q10 answered: greenfield optionality is a DR requirement.** And `mantle` is
   **currently greenfield-broken** by exactly this pattern: `data.external.forgejo_runner_token` reads
   the `forgejo-admin` Secret that `module.forgejo` creates in the *same* stack — `set -eu` +
   `kubectl get secret`, no fallback, so a from-scratch `mantle plan` **fails**. Moving the instance to
   `core` puts the Secret strictly **before** its reader and **fixes a real DR-blocking bug**. The split
   is therefore **necessary, not merely tidy** — this supersedes the Pass 4 "tidiness only" verdict.

## 3. Current state (facts / evidence)

- **On disk vs planned (READ THIS).** `modules/devops/forgejo/` is still the **original flat module**
  (`auth.tf backup.tf egress.tf helm.tf ingress.tf listener.tf locals.tf namespace.tf outputs.tf
  providers.tf storage.tf variables.tf`), used by `stacks/mantle/forgejo.tf` as `module.forgejo`. The
  forgejo provider, the push robot, and `forgejo_registry_repos` are **not present** — prototyped, then
  **parked/reverted**. **Everything in §4 is planned, not built.**
- **Stacks.** `core` modules: `network`, `storage`, `seaweedfs`, `cert_man`, `authentik`,
  `oidc_client_alias`, `harbor`, `argo`, `prometheus`, `metrics_server`, `hardware`, `smartctl`,
  `wireguard`. `mantle` modules: `forgejo`, `forgejo_runner`, `harbor_setup`, `argo_setup`,
  `authentik_ldap`, `alertmanager`, `grafana_oidc`, `documents`, `media`, `mcp`, `pastebin`,
  `passkey`, `passwordless`, `seaweedfs_admin`, `blender`, `vaultwarden`, `whisker`.
- **Module** `modules/devops/forgejo/` = auth, backup, egress, helm, ingress, listener, locals,
  namespace, outputs, providers, storage, variables.
- **Live.** ns `devops-forgejo`; helm release `forgejo` **rev 5**, chart **`forgejo-17.2.0`**
  (chart `appVersion` **15.0.9**), deployed image **`code.forgejo.org/forgejo/forgejo:16.0.5-rootless`**
  (module pins `image_tag = 16.0.5`, overriding the chart appVersion); PVC `forgejo-data`
  (20Gi longhorn, **`helm.sh/resource-policy: keep`**, volumeName `pvc-1c01d7ea-f753-4a61-ae70-44a4ad486c3d`);
  pod on `k8smaster`.
- **mantle state holds** `module.forgejo.*`: `kubernetes_namespace_v1.namespace`, `helm_release.forgejo`,
  and submodules `backup`, `bucket`, `egress`, `egress_gateway`, `egress_internet`, `expose`,
  `ingress`, `oidc`, `s3_user`.
- **authentik.** Instance built by `core` (`module.authentik`, ns `kube-auth`). Terraform API key
  Secret `authentik-tfdeploykey` whose value is `random_password.terraform_key`. Blueprints are
  delivered by the chart value **`blueprints.secrets = [<secret-name>]`** (worker mounts
  `blueprints-secret-<name>`). Auto-discovery by label is NOT used and NOT confirmed.
- **Safety net (Phase 0, DONE).** `.tmp/backups/{core,mantle}-20261013-093015.tfstate` +
  `*-secret-*.yaml`; Velero backup `forgejo-pre-split` **Completed 54/54**, PVB **8.33 GB** (kopia).
- **Known gaps.** Longhorn backup target DOWN (`backup target default is not available`); the
  `forgejo-data` Velero schedule **has now fired** (`status.lastBackup: 2026-10-13T03:00:42Z` — Pass 20,
  O20-2; DEF-2 was corrected earlier, this twin was missed).

## 4. Target state

### Module layout
- `modules/devops/forgejo/core/` — instance: namespace, helm, storage (bucket + s3_user),
  listener/expose, ingress, egress, backup. Takes the OIDC client as an **input** variable `oidc`. The
  stack must supply **exact** values or the rendered `app.ini` changes: `scopes = "openid,email,profile,groups"`,
  `group_claim = "groups"`, `admin_group = "forgejo-admin"`, `restricted_group = "forgejo-user"`, and
  `discovery_url = https://auth.<domain>/application/o/forgejo/.well-known/openid-configuration`
  (**note the slash after `forgejo`** — the old module built it from `${oidc_issuer_base}/application/o/${name}/`).
- `modules/devops/forgejo/mantle/` — CI integration: `harbor_robot_account` + `forgejo_*_action_secret`.
- `modules/auth/authentik/oidc_blueprint/` — **NEW**: emits an authentik **blueprint Secret**
  (cert/key + client secret templated in). **Outputs four things: `client_id`, `client_secret`,
  `discovery_url`, and `blueprint_secret`** (the Secret name `module.authentik` consumes below).
  *(Pass 20, O20-1: this said "exactly three" while the stack wiring below, §6 and T4.3 all consumed the
  fourth — implementing §4 literally and then wiring T4.3 would have failed `tofu validate` in Phase 4.)*
  The rest of the `oidc` input (`scopes`, `group_claim`, the group names) are stack literals (N3). The
  provider-based `oidc_provider` stays for every other app.
- `modules/auth/authentik/core/` — new input `extra_blueprints` (names appended to `blueprints.secrets`).

### Stack wiring
- `core`: `module "forgejo"` (forgejo/core) — the instance; `module "forgejo_oidc"` (oidc_blueprint) — the
  blueprint Secret + client creds; `module "authentik"` gains
  `extra_blueprints = [module.forgejo_oidc.blueprint_secret]`. **`core` must also gain the `tls` provider**
  (the blueprint module mints the signing cert).
- `mantle`: `module "forgejo_setup"` (forgejo/mantle) = the CI integration — `harbor_robot_account`
  (**`depends_on = [module.harbor_setup]` only at STACK scope** — see T3.3/P20; the old "targets project
  `library`" rationale was **wrong**: `harbor_setup` owns `linuxguru`, and `library` is Harbor's default
  public project) + repo-level Action
  secrets **`HARBOR_USER`** (= `robot$library+forgejo`) and **`HARBOR_TOKEN`**; `data "authentik_group"` for
  `forgejo-admin`/`forgejo-user`; the `forgejo` provider — **pinned to `svalabs/forgejo` 1.6.1**, authed the
  house way via a new `data "kubernetes_secret_v1"` on the chart-minted `forgejo-admin` Secret (`host =
  https://git.<domain>`, `username`/`password` from it — no new credential); the runner uses literals
  (`devops-forgejo`, `git.<domain>`).
  **Coupling note (N8):** after the split, `data.external.forgejo_runner_token` reads a Secret that **`core`
  now owns**, so a from-scratch `plan` of `mantle` requires a live `core` — the corollary of the DEF-10
  greenfield tenet. Mid-surgery it is harmless (nothing destroys that Secret).

## 5. Design decisions

- **D1 — OIDC via blueprint, not provider.** Solves (3) and (2). The blueprint runs in core with the helm.
- **D2 — Blueprint delivery: extend `blueprints.secrets` with the plan's own Secret.** The `oidc_blueprint`
  module creates a Secret (in `kube-auth`); `modules/auth/authentik/core` gains an `extra_blueprints`
  input taking **names** (never *content* — the IdP module must not import app YAML) and appends them to
  `blueprints.secrets`. The chart mounts blueprints on the **worker only**, so the resulting roll pauses
  background tasks/outpost sync but **does not interrupt login** (verified: `authentik-server` mounts no
  blueprint volume). Auto-discovery is unverified, so we use the explicit list. *This supersedes an earlier
  "inject the blueprint as a key into the bootstrap Secret" idea (historically tagged D7) — rejected,
  because it forces core's IdP module to import app-generated YAML and the rollout it dodged is harmless.*
- **D3 — Groups created by the blueprint** (`forgejo-admin`, `forgejo-user`); `mantle` looks them up
  with `data "authentik_group"`. Avoids cross-stack outputs (no `terraform_remote_state`).
  **⚠️ Pass 16 (C16-6): this is a NEW cross-stack read of an ASYNC producer.** The groups are created by
  the authentik **worker** when it ingests the blueprint (start-up or the 60-min scan, R9) — not at
  terraform-apply time. A `mantle plan` that beats the worker **fails**. Gate: after `core apply`, confirm
  both groups exist **before** planning mantle (T6.3c).
  Also (A16-4): the group names derive as `"${var.name}-admin"`/`"-user"` (`oidc_provider/auth.tf:157-163`),
  so the blueprint module's `name` **must be exactly `forgejo`** — otherwise authentik makes
  `forgejo-oidc-admin` while Forgejo is told to read `forgejo-admin`: login works, **nobody is admin, zero
  errors.** Pinned in T1.3.
- **D4 — Preserve authentik object identity.** Convert by **dropping** the `oidc` entries from the pushed
  mantle state (**forget**), NOT destroying them, so the blueprint **adopts** the existing
  app/provider/groups by identifier → UUIDs (and memberships) survive. Destroy+recreate would break the
  umbrella `admin`/`user` nesting in `mantle`.
- **D5 — Address-preserving state move.** Both stacks name the module `module.forgejo` with identical
  submodule paths, so state entries transplant **verbatim**. *(Correction, Pass 15: the earlier "because
  `terraform_data` cannot be imported" rationale is **wrong** — verified on OpenTofu 1.13.1 that
  `terraform_data` imports cleanly. JSON surgery is still the right method: it preserves object identity
  and cannot re-create anything.)*
- **D6 — Keep `client_id` = app slug `forgejo`; ROTATE the `client_secret`.** A new `random_password` feeds
  both the blueprint and the helm values in the same apply. Expect **one `update` to
  `helm_release.forgejo`** plus a brief window where the two disagree — accepted (D8). *Preservation is
  possible (the live secret round-trips in the export) but buys nothing here.*
  **⚠️ Pass 17 (E17-4): this interacts dangerously with any DB restore.** The OAuth source is a DB
  `login_source` **row**. Restoring an OLD database (old row) while the blueprint + helm carry the NEW
  `client_secret` makes the token endpoint reject — and **SSO fails silently**, because the login page still
  renders. Any restore must therefore either preserve the old secret or re-run the helm update (which
  re-syncs the row). **Restore order: DB first, then let the Forgejo pod come up, then exercise OIDC** — and
  re-check `login_source` after every restore.**
- **D8 — PRIORITY: availability is cheap, data is sacred** (owner, explicit). Service disruption is
  acceptable; data loss is not. Consequences: availability risks (**R3, R7, R9, R12**) are downgraded to
  footnotes; the gates narrow to **exactly two objects** — `kubernetes_namespace_v1.namespace` and
  `module.bucket.*`. A `helm_release.forgejo` destroy is **survivable** (the chart's PVC carries
  `helm.sh/resource-policy: keep`), so it is a disruption, **not** a data-loss event. Recovery may freely
  take a service gap. **(This also RETIRED the `depends_on = [module.authentik]` ordering constraint — it
  only guarded the R9 race, which D8 declares irrelevant. Do not add it.)**
- **D9 — DR landing zone for THIS migration: `/Users/jblack/backups/forgejo/`** (off-cluster, on the
  operator machine; documented in its own `README.md`). These are **DR backups for the surgery**, *not* a
  backup policy — the ongoing/normal backup process is a **separate topic** (`todo-backup-policy` in
  memory). Three pieces, because **no single tool covers it**: `dump/` =
  `forgejo dump` (git repos + SQLite DB + config, app-native, restores without k8s); `s3/` = a mirror of
  the SeaweedFS bucket **`forgejo`** (`lfs/`, `avatars/`, `repo-avatars/`, attachments, artifacts — all
  `[storage]` blobs); `tfstate/` = state pulls. Velero keeps its own in-cluster BSL. Rationale: data loss
  is the only unacceptable outcome (D8), and before this the whole story was **one perishable Velero copy**
  (**ttl 720h** — Pass 20, O20-4; the earlier "168h" was the *schedule's* ttl, not the backup's) — a
  `forgejo dump` alone is *incomplete*, because the blob data lives in S3, not `/data`.

Rejected: **A** (no split — leaves `mantle` **greenfield-broken**, violating the DR tenet, §2.5);
**C** (operator-provided authentik token in tfvars — violates the "tfvars is a symlink, don't touch" rule).

## 6. Major steps (high level)

1. **S0 — Safety** *(DONE)*: state backups, git commit, a Velero backup (note: its BSL is **in-cluster**,
   so it is not a second failure domain — DEF-13).
2. **S1 — Blueprint module.** Build `modules/auth/authentik/oidc_blueprint`; reproduce everything
   `oidc_provider` creates for Forgejo as blueprint entries (groups, scope mappings, signing cert,
   oauth2 provider, application, policy bindings). Verify on a scratch name before touching Forgejo.
3. **S2 — authentik core input.** Add `extra_blueprints` to `modules/auth/authentik/core`; append to
   `blueprints.secrets`.
4. **S3 — Module split.** Create `forgejo/core` (accept OIDC as input) and `forgejo/mantle`; retire the
   old module files.
5. **S4 — Stack wiring.** `core` instantiates `forgejo/core` + `oidc_blueprint` + `extra_blueprints`;
   `mantle` instantiates `forgejo/mantle` as **`module.forgejo_setup`**; swap `module.forgejo.*` refs
   (admins/users → data lookups; runner → literals).
6. **S5 — State surgery.** `tofu init` both stacks. Move `module.forgejo.*` **minus `module.oidc`** from
   mantle state to core state (**JSON pull/append/push**). The pushed mantle state already excludes *both*
   the moved entries **and** the `oidc` entries (forgotten, D4) — nothing is `state rm`'d.
7. **S6 — Apply core**, then **apply mantle**. Both plans must show **zero destroys on the namespace or the
   bucket** before any apply (D8).
8. **S7 — Verify & commit** (see VALIDATION).

## 6b. Auth surfaces — what is (and is NOT) OIDC

**Pass 19 (K19-1) traced the live request path and found that OIDC is NOT the only authentication surface in
front of Forgejo.** The OIDC work covers the *web login*; other surfaces exist:

- **The `private` gateway is a dumb TLS terminator** — NGINX Gateway Fabric, **no `filters`**, and no
  `SecurityPolicy` / `AuthenticationFilter` / middleware anywhere in the cluster, plus **no authentik proxy
  outpost** for `git.` (all 9 proxy providers serve other apps). So there is **no forward-auth wall** to
  migrate. And **`variable "auth_gateway_name"` is NOT auth** — it feeds a NetworkPolicy **egress peer**
  (`egress.tf:22`) carrying authentik **and** S3.
- **git-over-SSH is a separate, raw authN path** — `service/forgejo-ssh` is a `LoadBalancer` on a bare VIP
  (`:22`, open) with `START_SSH_SERVER=true`; it authenticates with **SSH keys**, bypassing OIDC, the gateway
  and TLS entirely.
- **`breakglass` basic-auth / API** — `ENABLE_PASSWORD_SIGNIN_FORM=false` hides the *form*, but basic auth
  still works (the runner's registration-token fetch proves it: `curl -u breakglass:<pw>`).
- **The runner's token** (`.runner` row `id:3`) rides on that and **survives the split** (neither pod nor DB
  row moves).

**None of these is disturbed by the split** — there is no forward-auth layer to disturb. The only hazards are
the already-known ones (the runner's cross-stack read, and losing the Gateway **ordering edge** because
`expose`/`egress` use the **literal** `"private"` instead of `module.network.gateway_name` — see C16-9).

## 7. Risks & mitigations

**Data-loss surface — the ONLY things that matter (D8).** `kubernetes_namespace_v1.namespace` (destroy →
cascade → PVC gone), `module.bucket.*` (SeaweedFS LFS/attachments/artifacts), and the PVC itself (not
terraform-managed). Everything else below is *availability*, which is **accepted**.

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| R1 | Move botched → terraform plans to **destroy the namespace** | Namespace delete cascades to the PVC → **data loss** | Never apply unless `plan` shows 0 destroys; backups in place; PVC is `keep`-annotated |
| R2 | authentik objects churn (destroy/recreate) | Group UUIDs change → umbrella `admin`/`user` nesting breaks | D4: **forget** (drop from the pushed state) so the blueprint adopts by identifier |
| R3 | Brief OIDC/login outage | Users can't SSO during cutover | **Accepted (D8)** — break-glass local admin stays available |
| R4 | State JSON surgery error | Corrupt state | Backups; validate JSON; `plan` dry-run gates each step |
| R5 | helm release **destroyed + recreated** | Forgejo restarts — **survivable** (PVC carries `keep`) → a disruption, not data loss (D8) | Expect exactly **one `update`** to `helm_release.forgejo` (new `client_secret`); a **`destroy` must not appear** (T5.7) |
| R6 | Blueprint syntax error | authentik worker logs error, OIDC app absent | Build+verify blueprint standalone first (S1) |
| R7 | client_secret rotation | Forgejo OAuth breaks until helm updates | Accept rotation; ensure helm update lands in the same apply |
| R8 | Blueprint **fidelity** — `grant_types`, token validities, redirect URIs, `property_mappings` must byte-match today's provider | SSO **silently** breaks (role mapping / all flows rejected) | Copy every field from `oidc_provider/auth.tf` verbatim; diff against §10 |
| R9 | authentik applies blueprints **asynchronously**; terraform returns "success" first | Window where Forgejo points at a provider that doesn't exist; **silent** failure if malformed | Worker-log + app-exists checks (V-C1/V-C2); expect a short window |
| R10 | Blueprints mount on the **worker only** | A server-only restart applies nothing | Confirm the worker rolled out (T6.3b) |
| R11 | `client_secret` rotation desyncs authentik vs helm | OIDC breaks until both converge | Preserve the secret (Q2) or land both in one apply |
| R12 | The authentik **worker** rolls (blueprint list changes) | Background tasks / outpost sync pause briefly — **login is NOT affected** (`authentik-server` mounts no blueprints) | Low impact; verify other apps after (V-C10) |

| R13 | **The Actions repo-unit is globally DISABLED** — live `app.ini` has `[repository] DISABLED_REPO_UNITS = repo.actions`, set by **no `.tf`** (stale PVC drift) | The goal's **second half** (Harbor robot → repo action secrets) is **inert**: every `forgejo_repository_action_secret` 404s (verified on all 86 repos) | **G18-1 — the biggest find of the 18 passes.** Set `DISABLED_REPO_UNITS = ""` + enable the unit per repo; gate on `GET .../actions/secrets == 200` (**T3.8**) |

> **Under D8, everything except R1 is non-data-loss.** R3/R5/R7/R9/R11/R12 are *availability* — accepted, no
> mitigation. R2/R6/R8 are *config* risks (fix forward). **R13 is a *goal* risk** — no data at stake, but the
> change would ship without delivering half its purpose. **R1 is the only data-loss row**, and
> `module.bucket.*` is the other untouchable object.

## 8. Rollback

> **Pass 16 rewrote this section** — as originally written it **did not work**. The push command omitted
> `-force`, and after surgery the backups carry *older* serials (mantle 1169 vs 1170, core 783 vs 784), so
> terraform **refuses** the push exactly when you need it (R16-1). Worse, "restore both states, then
> `tofu apply` to converge back" is a **data-loss trap** (R16-2).

**Golden rule: Phase 5 is STATE-ONLY — never run `apply` until both plans are clean.** After a botched move
a stack's state and config disagree, so its plan renders a `destroy` on `kubernetes_namespace_v1.namespace`
(cascading to the PVC) or `module.bucket.*`. One careless `apply` acts on it and **creates a fresh, empty
PVC** — silent data loss, the one outcome D8 forbids.

### Rollback drill (exact, in order)

0. **Set these TWO variables FIRST.** (Pass 18, H18-1: the drill below used `$TS`, which was never defined
   here, and a *relative* `.tmp/…` that resolves under `stacks/<stack>/` after the `cd` — so it died on
   line 1.)
   ```sh
   ROOT=/Users/jblack/code/k8s/terraform     # or: git rev-parse --show-toplevel
   TS=<timestamp of the pre-Phase-5 backups> # ls "$ROOT/.tmp/backups/" to find it
   ```
1. **STOP. Apply nothing.** Freeze both stacks.
2. Revert code: `git checkout -- . && git clean -fd modules/ stacks/` — note the new module dirs are
   **untracked**, so `checkout` alone will not remove them.
3. **Push CORE first, then MANTLE (reverse of the forward order)** — never apply between them:
   - `cd "$ROOT/stacks/core"   && tofu state push -force "$ROOT/.tmp/backups/core-$TS.tfstate"   && tofu plan`  → *No changes*
   - `cd "$ROOT/stacks/mantle" && tofu state push -force "$ROOT/.tmp/backups/mantle-$TS.tfstate" && tofu plan`  → *No changes*
   `-force` is **required** (older serial); it also clobbers post-botch state changes, which is what we want.
   **Always use the absolute `"$ROOT/…"` form** — the `cd` silently changes what a relative path means.
4. Only when **both** plans say *No changes* may anything be applied — and nothing should need it.
5. Verify PVC identity survived:
   `kubectl -n devops-forgejo get pvc forgejo-data -o jsonpath='{.spec.volumeName}'` (must be unchanged).
6. **If a destroy already applied:** `velero restore create --from-backup forgejo-pre-split`. That is now the
   *only* recovery path — see the D9 note: the off-cluster vault is **empty** (R16-3).

- **authentik mis-applied:** `helm -n kube-auth rollback authentik 18` (last known-good rev) **before**
  re-applying core. A bad blueprint is inert alone (atomic apply).
- **Rollback gate:** if either plan shows a `destroy` on `kubernetes_namespace_v1.namespace` or
  `module.bucket.*`, STOP and run the drill. (Per D8 a `helm_release.forgejo` destroy is survivable, and a
  service gap during any restore is acceptable.)

## 9. Questions — answered (research pass 6)

Answers are from authentik's own docs (`blueprints/v1/models.mdx`, `tags.mdx`) and a **live export**:
`kubectl -n kube-auth exec deploy/authentik-worker -- ak export_blueprint > .tmp/authentik-export.yaml`.
That export is a **ready-made blueprint template** for every object, incl. the Forgejo provider.

| # | Question | **Answer** |
|---|----------|-----------|
| Q1 | Blueprint delivery | **Extend `blueprints.secrets`** with the plan's Secret (**D2**): the chart mounts it on the **worker only**; authentik discovers `*.yaml` on worker start or the periodic scan (default **60 min**). **No login impact.** |
| Q2 | `client_secret` rotation | **Preservable** — the export prints the current secret in clear (`client_secret: ElCZ…`), so the blueprint can carry the exact value. Otherwise a new `random_password` rotates it. |
| Q3 | Robot secret target | **Repo-level** (`forgejo_repository_action_secret`). The provider has no user-secret resource, and the publishing repos live under user `jblack/*`. |
| Q4 | `policybinding` refs | **Both Forgejo bindings sit at `order: 0` on the same target**, so `{target, order}` cannot tell them apart (`.first()` returns one row for both). Identify by **`{target, group}`**: `identifiers: {target: !Find [authentik_core.application,[slug,forgejo]], group: !Find [authentik_core.group,[name,forgejo-admin]]}`, plus exactly one of `policy`/`group`/`user` in `attrs`. |
| Q5 | `certificatekeypair` | `attrs: {name, certificate_data, key_data}` (PEMs from `tls_*`); identify by `name`. Note the export **omits** cert/key (write-only) → we must supply them. |
| Q6 | Preset `client_secret` honoured? | **Yes** — it's a model field on the provider and it round-trips in the export. |
| Q7 | Built-in scope mappings | `!Find [authentik_providers_oauth2.scopemapping, [managed, "goauthentik.io/providers/oauth2/scope-openid"]]` (also `scope-email`, `scope-offline_access`). Custom `groups`/`profile` mappings: **identify by `name`** (unique per app) — `scope_name` repeats across apps (immich has its own `profile`). |
| Q8 | `oauth2provider` identifier | Blueprint `identifiers` are just **model fields** → use `identifiers: {name: forgejo}` to **adopt pk 57**. (`client_id: forgejo` works too.) |
| Q9 | `tls_*` signing pair | **Let it regenerate.** The blueprint must carry the PEMs anyway; preserving would require keeping a same-path `module.oidc` shim. Cost: one re-login. |
| Q10 | Greenfield rebuilds required? | **YES — DR tenet (answered).** Greenfield build-out must stay possible, and `mantle` is *currently* greenfield-broken by the same-stack runner-token read (§2.5). ⇒ **the split is justified and fixes a real bug**; Option A is off the table. |

### Fidelity details discovered (extend R8 — get these EXACT)
- The model field is **`redirect_uris`**, *not* `allowed_redirect_uris`.
- Must byte-match: `grant_types` (7 entries: authz_code, hybrid, implicit, client_credentials, password,
  device_code, refresh_token), `access_token_validity: days=7`, `refresh_token_validity: days=30`,
  `access_code_validity: minutes=1`, `sub_mode: hashed_user_id`, `issuer_mode: per_provider`,
  `include_claims_in_id_token: true`, `logout_method: backchannel`, `client_type: confidential`,
  `refresh_token_threshold: seconds=0`.
- `authorization_flow` **and** `invalidation_flow` are both the `default-provider-authorization-implicit-consent` flow.
- `property_mappings` = 5: custom `groups`+`profile`, built-in `openid`+`email`+`offline_access`.
- Application: `slug`/`name` = `forgejo`, `provider`, `meta_icon`, `meta_launch_url`, `open_in_new_tab: true`,
  `policy_engine_mode: any`.
- **`signing_key`** — the live provider points at cert pk `4f322590…`. Adoption-by-`name` preserves that
  pk, but **set it explicitly** (`signing_key: !Find [authentik_crypto.certificatekeypair, [name,
  forgejo-signing]]`) so it can never silently resolve to a new cert; losing the signing key invalidates
  every issued token.
- **`client_secret` must be ASCII** — authentik's `validate_client_secret` rejects non-ASCII, so the
  `random_password` needs `special = false` (or an ASCII-safe `override_special`).
- `client_secret` in `attrs` is re-applied on **every** apply — keep the value stable (a terraform
  `random_password` is) or you rotate the OAuth client on each run and break Forgejo's baked `app.ini`.
- **Blueprints are atomic** — one bad entry rolls back the whole blueprint (good: no partial state).
- `metadata.labels.blueprints.goauthentik.io/instantiate: "false"` disables auto-instantiation (escape hatch).


## 10. Pre-change baseline (captured 2026-10-13, from `mantle-<ts>.tfstate`) — the D4 reference

Objects the blueprint must **adopt by identifier** (so their UUIDs survive). Verified live.

| state address | UUID / id | identifier |
|---|---|---|
| `authentik_group.admin` | `e99a0ce2-3e14-4921-9f35-f006938097c1` | name `forgejo-admin` |
| `authentik_group.user` | `0e04476d-b7c6-46e7-98a4-f0035035a183` | name `forgejo-user` |
| `authentik_provider_oauth2.oauth2` | `57` (pk) | name `forgejo` |
| `authentik_application.app` | slug `forgejo` | slug `forgejo` |
| `authentik_certificate_key_pair.signing` | `4f322590-d2d4-48c8-9c4b-0f89ffe49120` | name `forgejo-signing` |
| `authentik_property_mapping_provider_scope.groups` | `27624d7b-6021-4e36-8ce8-9dc4ea4c52ec` | name `OpenID 'groups' (forgejo)` |
| `authentik_property_mapping_provider_scope.profile` | `db829461-472d-4d51-8e69-54c36e929264` | name `OpenID 'profile' (forgejo)` |
| `authentik_policy_binding.own_groups["admin"]` | `20e35690-e8a4-4734-a79f-e2535b0aa6fe` | target+group |
| `authentik_policy_binding.own_groups["user"]` | `3d4decc6-7875-40df-be54-034da85019f6` | target+group |

Also in the oidc submodule (data sources — re-read on next plan, nothing to preserve): the two default
flows (`fbfe9f96-7fcf-450e-b067-a9328f109730`) and the built-in scope mappings `email` / `openid` /
`offline_access`.

## 11. Execution notes

Findings from **all** passes are folded in: risks **R8–R12** live in §7, questions **Q6–Q10** in §9,
decisions **D1–D9** in §5. The narrative for every pass is in
`FORGEJO-SPLIT-REVIEWS.md`.

### Gaps found and closed as tasks

Seven gaps surfaced across the passes; each is now a **task in the checklist** (with its reason inline):
`T3.3` (robot's `depends_on`), `T3.6`/`T3.7` (repo list + variable), `T4.9` (core `tls` provider),
`T4.10` (blueprint Secret → `kube-auth`), `T5.10` (manifest move, no diff), `T6.3b` (worker roll).

### State move dry-run (verified, no push)

```
mantle total 477  ->  move 18  |  forget 15 (oidc)  |  stay 444
providers moved   : kubectl, helm, kubernetes, random, builtin/terraform   (ALL present in core)
collision check   : clean (core owns none of the moved addresses)
stale deps        : none
```

Module paths moved: `module.forgejo` + `module.forgejo.module.{backup,bucket,egress,egress_gateway,
egress_internet,ingress,s3_user,expose.module.http_route[0],expose.module.listener_set}` — **all
addresses identical to what `forgejo/core` will produce** (same module + submodule names), so the
entries transplant verbatim. Drop-out trap (`module.forgejo_runner` also starts with `module.forgejo`)
is guarded in the script. Phase 5 carries the exact commands (see checklist).

### Dependency DAG — proven acyclic

```
module.forgejo_oidc  (secret in kube-auth, random_password, tls)   -- no deps
        |
        +--> module.authentik        (input extra_blueprints = [forgejo_oidc.blueprint_secret])
        |
        +--> module.forgejo (core)   (input oidc = forgejo_oidc.{client_id,client_secret,discovery_url} + literals)
```
**Pass 16 correction: this is a FORK, not a chain** — `forgejo_oidc → {authentik, forgejo}`, with **no**
`forgejo_oidc → authentik → forgejo` edge (D8 retired the only `authentik→forgejo` edge). Acyclic either
way, so the conclusion holds; the drawn chain was wrong. It stays acyclic only because `forgejo_oidc`
derives its redirect URI, group names and launch URL from **vars**, never from `module.forgejo`.
**No `depends_on` is needed *here*** — but see T4.1: the moved module DOES need `depends_on` on the
**producers it inherited for free** from cross-stack sequencing.




