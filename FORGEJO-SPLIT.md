# Forgejo core/mantle split — PLAN

Status: REVIEWED — passes 1–6 complete, Q1–Q10 answered · Owner: jblack · Scope: `stacks/core`, `stacks/mantle`, `modules/devops/forgejo*`, `modules/auth/authentik*`

## 1. Goal

Move the Forgejo **instance** (helm release, namespace, storage, exposure, backup) out of the `mantle`
stack and into `core`, re-implement Forgejo's authentik OIDC as an authentik **blueprint** (so no
authentik terraform provider is needed in core), and **add** the **forgejo terraform provider** +
Harbor push robot + Actions secrets in `mantle` — **none of that exists yet** (see §3). Constraint:
**zero Forgejo data loss**. Expected disruption: a **brief Forgejo pod restart** (its helm values change)
plus **one SSO re-login**; the authentik *worker* roll does **not** interrupt login.

**PRIORITY (owner, explicit): short service disruption is acceptable; data loss is not.** So the plan
optimises for **exactly one thing — zero data loss**. Every availability concern (pod restarts, SSO gaps,
worker rolls, the OIDC window, downtime during a restore) is a **non-issue**, and the gates say so (D8).

## 2. Why (root causes)

1. **Provider bootstrap.** A terraform provider used by a stack must target something that already
   exists. Harbor and Argo follow the house pattern — *instance in `core`, provider + setup in
   `mantle`*. Forgejo is the lone exception: its instance is in `mantle`.
2. **OIDC must co-reside with the helm release.** Forgejo's OIDC client is baked into `app.ini` at
   install time via helm values, so the client_id/secret must be known when `helm_release` applies.
   Whatever creates those creds must live with the helm release.
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
  `forgejo-data` Velero schedule has never fired (first 03:00Z run not yet reached).

## 4. Target state

### Module layout
- `modules/devops/forgejo/core/` — instance: namespace, helm, storage (bucket + s3_user),
  listener/expose, ingress, egress, backup. Takes the OIDC client as an **input** variable.
- `modules/devops/forgejo/mantle/` — CI integration: `harbor_robot_account` + `forgejo_*_action_secret`.
- `modules/auth/authentik/oidc_blueprint/` — **NEW**: emits an authentik **blueprint Secret**
  (cert/key + client secret templated in); outputs client_id/secret + group names. The provider-based
  `oidc_provider` stays for every other app.
- `modules/auth/authentik/core/` — new input `extra_blueprints` (names appended to `blueprints.secrets`).

### Stack wiring
- `core`: `module "forgejo"` (forgejo/core), `module "forgejo_oidc"` (oidc_blueprint),
  `module "authentik"` gains `extra_blueprints = [module.forgejo_oidc.blueprint_secret]`.
- `mantle`: `module "forgejo"` (forgejo/mantle) = robot + secrets; `data "authentik_group"` for
  `forgejo-admin`/`forgejo-user`; forgejo provider; runner uses literals (`devops-forgejo`, `git.<domain>`).

## 5. Design decisions

- **D1 — OIDC via blueprint, not provider.** Solves (3) and (2). The blueprint runs in core with the helm.
- **D2 — Blueprint delivery = extend `blueprints.secrets`.** Auto-discovery unverified; use the proven
  mechanism. Cost: an authentik helm update (worker restart) when the list changes.
- **D3 — Groups created by the blueprint** (`forgejo-admin`, `forgejo-user`); `mantle` looks them up
  with `data "authentik_group"`. Avoids cross-stack outputs (no `terraform_remote_state`).
- **D4 — Preserve authentik object identity.** Convert by **dropping** the `oidc` entries from the pushed
  mantle state (**forget**), NOT destroying them, so the blueprint **adopts** the existing
  app/provider/groups by identifier → UUIDs (and memberships) survive. Destroy+recreate would break the
  umbrella `admin`/`user` nesting in `mantle`.
- **D5 — Address-preserving state move.** Both stacks name the module `module.forgejo` with identical
  submodule paths, so state entries transplant **verbatim**. Required because `terraform_data.bucket`
  / `terraform_data.user` **cannot be imported**.
- **D6 — Keep `client_id` (= app slug `forgejo`) stable; `client_secret` may rotate** (acceptable; the
  helm values update and the pod reconfigures once).

- **D8 — PRIORITY: availability is cheap, data is sacred** (owner, explicit). Service disruption is
  acceptable; data loss is not. Consequences: availability risks (**R3, R7, R9, R12**) are downgraded to
  footnotes; the gates narrow to **exactly two objects** — `kubernetes_namespace_v1.namespace` and
  `module.bucket.*`. A `helm_release.forgejo` destroy is **survivable** (the chart's PVC carries
  `helm.sh/resource-policy: keep`), so it is a disruption, **not** a data-loss event. Recovery may freely
  take a service gap.

- **D9 — DR landing zone for THIS migration: `/Users/jblack/backups/forgejo/`** (off-cluster, on the
  operator machine; documented in its own `README.md`). These are **DR backups for the surgery**, *not* a
  backup policy — the ongoing/normal backup process is a **separate topic** (`todo-backup-policy` in
  memory). Three pieces, because **no single tool covers it**: `dump/` =
  `forgejo dump` (git repos + SQLite DB + config, app-native, restores without k8s); `s3/` = a mirror of
  the SeaweedFS bucket **`forgejo`** (`lfs/`, `avatars/`, `repo-avatars/`, attachments, artifacts — all
  `[storage]` blobs); `tfstate/` = state pulls. Velero keeps its own in-cluster BSL. Rationale: data loss
  is the only unacceptable outcome (D8), and before this the whole story was **one perishable Velero copy**
  (ttl 168h) — a `forgejo dump` alone is *incomplete*, because the blob data lives in S3, not `/data`.

Rejected: **A** (no split — leaves `mantle` **greenfield-broken**, violating the DR tenet, §2.5);
**C** (operator-provided authentik token in tfvars — violates the "tfvars is a symlink, don't touch" rule).

- **D7 — Blueprint delivery: extend `blueprints.secrets` with the plan's own Secret.** The `oidc_blueprint`
  module creates a Secret (in `kube-auth`); `modules/auth/authentik/core` gains an `extra_blueprints`
  input taking **names** (never *content* — the IdP module must not import app YAML) and appends them to
  `blueprints.secrets`. The chart mounts blueprints on the **worker only**, so the resulting roll pauses
  background tasks/outpost sync but **does not interrupt login** (verified: `authentik-server` mounts no
  blueprint volume). A previous idea — injecting the blueprint as an extra *key* into the bootstrap
  Secret to dodge the rollout — is **rejected**: it forces core's IdP module to import app-generated
  YAML, and the rollout it avoids is harmless.

## 6. Major steps (high level)

1. **S0 — Safety** *(DONE)*: state backups, git commit, off-box Velero backup.
2. **S1 — Blueprint module.** Build `modules/auth/authentik/oidc_blueprint`; reproduce everything
   `oidc_provider` creates for Forgejo as blueprint entries (groups, scope mappings, signing cert,
   oauth2 provider, application, policy bindings). Verify on a scratch name before touching Forgejo.
3. **S2 — authentik core input.** Add `extra_blueprints` to `modules/auth/authentik/core`; append to
   `blueprints.secrets`.
4. **S3 — Module split.** Create `forgejo/core` (accept OIDC as input) and `forgejo/mantle`; retire the
   old module files.
5. **S4 — Stack wiring.** `core` instantiates `forgejo/core` + `oidc_blueprint` + `extra_blueprints`;
   `mantle` instantiates `forgejo/mantle`; swap `module.forgejo.*` refs (admins/users → data lookups;
   runner → literals).
6. **S5 — State surgery.** `tofu init` both stacks. Move `module.forgejo.*` **minus `module.oidc`** from
   mantle state to core state (**JSON pull/append/push**). The pushed mantle state already excludes *both*
   the moved entries **and** the `oidc` entries (forgotten, D4) — nothing is `state rm`'d.
7. **S6 — Apply core**, then **apply mantle**. Both plans must show **zero destroys** before any apply.
8. **S7 — Verify & commit** (see VALIDATION).

## 7. Risks & mitigations

**Data-loss surface — the ONLY things that matter (D8).** `kubernetes_namespace_v1.namespace` (destroy →
cascade → PVC gone), `module.bucket.*` (SeaweedFS LFS/attachments/artifacts), and the PVC itself (not
terraform-managed). Everything else below is *availability*, which is **accepted**.

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| R1 | Move botched → terraform plans to **destroy the namespace** | Namespace delete cascades to the PVC → **data loss** | Never apply unless `plan` shows 0 destroys; backups in place; PVC is `keep`-annotated |
| R2 | authentik objects churn (destroy/recreate) | Group UUIDs change → umbrella `admin`/`user` nesting breaks | D4: **forget** (drop from the pushed state) so the blueprint adopts by identifier |
| R3 | Brief OIDC/login outage | Users can't SSO during cutover | Break-glass local admin stays; do it in a quiet window |
| R4 | State JSON surgery error | Corrupt state | Backups; validate JSON; `plan` dry-run gates each step |
| R5 | helm release recreated | Forgejo restarts, possible PVC re-bind | Plan must show no change to `helm_release.forgejo`; PVC `keep` |
| R6 | Blueprint syntax error | authentik worker logs error, OIDC app absent | Build+verify blueprint standalone first (S1) |
| R7 | client_secret rotation | Forgejo OAuth breaks until helm updates | Accept rotation; ensure helm update lands in the same apply |
| R8 | Blueprint **fidelity** — `grant_types`, token validities, redirect URIs, `property_mappings` must byte-match today's provider | SSO **silently** breaks (role mapping / all flows rejected) | Copy every field from `oidc_provider/auth.tf` verbatim; diff against §10 |
| R9 | authentik applies blueprints **asynchronously**; terraform returns "success" first | Window where Forgejo points at a provider that doesn't exist; **silent** failure if malformed | Worker-log + app-exists checks (V-C1/V-C2); expect a short window |
| R10 | Blueprints mount on the **worker only** | A server-only restart applies nothing | Confirm the worker rolled out (T6.3b) |
| R11 | `client_secret` rotation desyncs authentik vs helm | OIDC breaks until both converge | Preserve the secret (Q2) or land both in one apply |
| R12 | The authentik **worker** rolls (blueprint list changes) | Background tasks / outpost sync pause briefly — **login is NOT affected** (`authentik-server` mounts no blueprints) | Low impact; verify other apps after (V-C10) |

> **R3, R7, R9, R12 are *availability* concerns — ACCEPTED (D8).** No mitigation required; they cost a
> brief service gap at most. The only rows that matter are the data-loss ones (R1, and R2/R5 insofar as
> they could cascade).

## 8. Rollback

- **Before any apply:** `git checkout` the changes; restore state with
  `tofu state push .tmp/backups/<stack>-<ts>.tfstate` (or re-import from the `.yaml` Secret dumps).
- **After a bad apply:** restore both states from backups, then `tofu apply` to converge back; worst
  case, restore the Forgejo PVC contents from the Velero backup `forgejo-pre-split`.
- **authentik mis-applied:** roll the release back — `helm -n kube-auth rollback authentik 18` (last
  known-good rev) — **before** re-applying core. A bad blueprint is inert on its own (atomic apply).
- **Rollback gate:** if `plan` (either stack) shows a `destroy` on `kubernetes_namespace_v1.namespace` or
  `module.bucket.*`, STOP and restore. (Per D8 a `helm_release.forgejo` destroy is survivable, and a
  service gap during any restore is acceptable.)

## 9. Questions — answered (research pass 6)

Answers are from authentik's own docs (`blueprints/v1/models.mdx`, `tags.mdx`) and a **live export**:
`kubectl -n kube-auth exec deploy/authentik-worker -- ak export_blueprint > .tmp/authentik-export.yaml`.
That export is a **ready-made blueprint template** for every object, incl. the Forgejo provider.

| # | Question | **Answer** |
|---|----------|-----------|
| Q1 | Blueprint delivery | **Extend `blueprints.secrets`** with the plan's Secret (**D7**): the chart mounts it on the **worker only**; authentik discovers `*.yaml` on worker start or the periodic scan (default **60 min**). **No login impact.** |
| Q2 | `client_secret` rotation | **Preservable** — the export prints the current secret in clear (`client_secret: ElCZ…`), so the blueprint can carry the exact value. Otherwise a new `random_password` rotates it. |
| Q3 | Robot secret target | **Repo-level** (`forgejo_repository_action_secret`). The provider has no user-secret resource, and the publishing repos live under user `jblack/*`. |
| Q4 | `policybinding` refs | `identifiers: {target: !Find [authentik_core.application,[slug,forgejo]], order: N}` + **exactly one** of `policy`/`group`/`user` in `attrs`. |
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
decisions **D1–D7** in §5. The narrative for every pass — passes 1–6 plus the hostile **Pass 8** — is in
`FORGEJO-SPLIT-REVIEWS.md`.

### Gaps found and closed as tasks

1. `stacks/core` has **no `tls` provider** — the `oidc_blueprint` needs it. → **T4.9**
2. `oidc_blueprint` writes its Secret into **`kube-auth`**; needs a `namespace` input + the namespace
   resource as a dependency. → **T4.10**
3. Serialize: `module.forgejo` (core) `depends_on = [module.authentik]` so the helm update can't race the
   worker's blueprint apply (R9). → **T4.11**
4. `kubernetes_manifest` move must yield **no diff**. → **T5.10** / **V-A7**
5. `s3_user` secrets must **not** rotate (a rotation breaks Forgejo→SeaweedFS). → **V-B8**
6. The Velero schedule must survive the move. → **V-B9**
7. Blueprints mount on the **worker only** → worker roll-out check. → **T6.3b**

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
        +--> module.forgejo (core)   (input oidc = forgejo_oidc.*  AND  depends_on = [module.authentik])
```
`forgejo_oidc → authentik → forgejo` — acyclic. It only stays acyclic because `forgejo_oidc` derives its
redirect URI, group names and launch URL from **vars**, never from `module.forgejo`.

**Refinement:** `depends_on = [module.authentik]` orders the *helm updates* only — **not** the async
blueprint apply (R9); the post-apply check remains the real guard.




