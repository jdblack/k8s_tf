# Forgejo core/mantle split — WORK CHECKLIST

Legend: `[ ]` todo · `[x]` done · `[~]` in progress · `[!]` blocked · `[?]` decision needed
Gate marker: **⛔ GATE** = do not proceed until the stated check passes.

---

## Phase 0 — Safety (DONE)

Done 2026-10-13: state pulls + backend-Secret dumps (`.tmp/backups/`), pre-change authentik UUID baseline
(plan §10), Velero backup `forgejo-pre-split` (Completed 54/54), git committed (`4513f9c`), `.tmp/`
gitignored.

- [x] **T0.7 — RE-TAKEN 2026-10-13 (`TS=20261013-120046`), after the Pass-21 apply bumped the mantle serial.**
  The move dry-run was re-run on the fresh set and reproduced the frozen audit **exactly** (477 → 18/15/444,
  collision clean, no dep escapes). **Still re-take immediately before Phase 5** — any further apply drifts
  them again.

> **Backup home (D9).** ✅ **Pass 22: the vault is POPULATED** (it was empty as of Pass 16/R16-3 — that is
> now superseded). `/Users/jblack/backups/forgejo/` holds `dump/forgejo-20261013-115216.tar.gz`
> (**8.34 GB, `gzip -t` OK, 87/87 repos + `app.ini` + `forgejo.db`**), `s3/` (owner's hand-sync, 1.1 GB),
> and `tfstate/` (core 783, mantle 1170 = live). Two
> Velero backups are `Completed` (`forgejo-pre-split`, `forgejo-data-20261013030042`) but their BSL is
> **in-cluster** (DEF-13), so the off-cluster vault is still the copy that matters. **T6.0 must still
> RE-TAKE the set immediately before the apply** (this set predates the split) — and the open DR gap is now
> the **restore drill** (DEF-14), not the backups. `.tmp/backups/` remains the *transient* working area.
>
> **Which is authoritative?** For **the surgery**, `.tmp/backups/` — the Phase-5 commands pull there and
> the move script reads there, and only those files are ever `state push`ed. **D9** is the *durable DR
> vault* (longer retention, off-cluster). T6.0 takes both; they are not interchangeable.

---

## Phase 1 — Forgejo OIDC blueprint module (build + verify in isolation)

- [x] T1.1 Enumerate the objects `modules/auth/authentik/oidc_provider/auth.tf` creates (done: 192 lines)
- [x] T1.2 Blueprint schema **now pinned** (plan §9): model names, identifiers, `!Find`/`!KeyOf`, and the
      atomic-apply + 60-min discovery behaviour.
      **⚠️ Pass 17 (D17-1): the matching mechanism FAILS OPEN.** `!Find` with **no** match returns `None` —
      not an error — and `.first()` has **no multi-match guard**; a live test on the worker
      (`Importer._apply_models()` inside a rollback) showed a provider adopting successfully with
      **`signing_key=None`** and `apply_ok=True`. Therefore: **use `!KeyOf` to same-blueprint entries for
      every FK reference**, and order the `certificatekeypair`/group entries **before** anything that refers
      to them. A missed match usually creates a **duplicate** (loud only where `name` is unique —
      **`policybinding` is the one model that can duplicate silently**, its `unique_together` being defeated
      by a NULL `policy`).
      **⚠️ Pass 24 — refine the rule to where fail-open actually bites.** D17-1's evidence (the
      `signing_key=None` provider) is the **nullable-SCALAR-FK** case, and that is the only silent one. Probes
      on 2026.8.2: a `!Find` miss inside a **list** (`property_mappings`) is **LOUD** — the serializer raises
      `Invalid pk "None" - object does not exist.`, `VALID: False`, and the whole blueprint is rejected
      (atomic apply). So: **`!KeyOf` for every *scalar* FK** (that is where a miss is invisible); lists are
      self-protecting, so the blanket "every FK" phrasing overstated it. Ordering
      (`certificatekeypair`/groups before referrers) is unchanged.
- [x] T1.2b **Use the live export as the template:**
      `kubectl -n kube-auth exec deploy/authentik-worker -- ak export_blueprint > .tmp/authentik-export.yaml`
      then copy-and-trim the Forgejo provider/application/mappings/bindings (already saved at
      `.tmp/authentik-export.yaml`)
      **⛔ PASS 24 — `redirect_uris` is a REQUIRED serializer field.** A probe that was testing something else
      still failed with `'redirect_uris': ['This field is required.']`. The template must **always** emit it
      non-empty — the two URIs below are not optional polish, they are what stops the entry being rejected.
      **⛔ PASS 23 — NEVER emit relation lists for the groups.** The export carries `users: [5]`, `parents: []`
      and `roles: []` on `forgejo-admin` (verified). "Copy-and-trim" done naively therefore **re-writes group
      membership** — and the umbrella `admin`/`user` nesting in `mantle` depends on it. Emit `name` (plus
      `attributes`/`is_superuser` if needed) and **nothing else**.
- [x] T1.3 Create `modules/auth/authentik/oidc_blueprint/` (variables, providers, locals,
      `blueprint.tftpl`, main, outputs).
      **⛔ `name` MUST be exactly `"forgejo"`** (**A16-4**). The groups derive as `"${var.name}-admin"` /
      `"-user"` (`oidc_provider/auth.tf:157-163`), and the app/provider adopt by `name` too — any other
      value makes authentik create `forgejo-oidc-admin` while Forgejo is told to read `forgejo-admin`:
      **login works, nobody is admin, zero errors.**
      **⛔ The Secret's KEY must end in `.yaml`** (**F17-4**). authentik discovers only `*.yaml` inside the
      mounted Secret — proof in-repo: `modules/auth/authentik/core/scopes.tf` writes **`terraform.yaml`**
      (applied) *and* **`api_key`** (silently ignored) into the same Secret. Since `extra_blueprints` is a
      `list(string)` of **names**, it *cannot* express the key: this module must write e.g. `forgejo.yaml`,
      or the blueprint validates, mounts, and is **never applied**.
      **⛔ PASS 24 — pick the Secret NAME and its `.yaml` KEY once, then never touch them.** `BlueprintInstance`
      has `unique_together = (name, path)` (`blueprints/models.py:85-90`). Renaming the Secret or renaming the
      key changes the `path`, which **orphans the old instance** (a stale row pointing at an unresolvable path)
      *and* creates a **second** one. Live rows confirm the mechanics: the working instance is
      `'Terraform Deploy key' | mounted/secret-authentik-tfdeploykey/terraform.yaml | successful` — a third
      independent confirmation of F17-4, this time from the DB, with **no row at all** for the sibling
      `api_key` key.
- [x] T1.4 Reproduce: `forgejo-admin`/`forgejo-user` groups; `groups` + `profile` scope mappings
      (custom expressions); signing cert/key pair (PEMs from `tls_*`); oauth2 provider (client_id = app
      slug, client_secret from `random_password`, built-in flows via `!Find`, property mappings,
      `redirect_uris` *(the model field — do **not** emit `allowed_redirect_uris`, the terraform attr name)*,
      `grant_types`); application; policy bindings for both groups.
      **Two** redirect URIs, not one: the callback **and** the site root `https://git.<domain>`
      (the old `extra_redirect_uris`). Do **not** carry an `email_verified` scope mapping — Forgejo uses
      the built-in `email` mapping.
      **Pin the exact `discovery_url`** (**A16-3**):
      `https://auth.<domain>/application/o/forgejo/.well-known/openid-configuration` — note the
      `application/o/` prefix and **no trailing slash**. A wrong path is a loud 500 (caught by V-C5), so
      this is a verification, not a silent risk.
- [x] T1.5 **⛔ GATE — drive it via `ak shell` + `Importer.from_string`, NOT `apply_blueprint <path>`
      (rewritten Pass 24 — the Pass-23 version of this item *could not run*).**
      **Why the obvious command fails:** `BlueprintInstance(path=…).retrieve()` → `retrieve_file()` resolves
      the path under `blueprints_dir` and raises **`BlueprintRetrievalFailed: Invalid blueprint path`** for
      anything outside it (`blueprints/v1/models.py:104-119`, the containment guard). And `/blueprints` is
      **not** a workaround: it is `root:root 0755` while the worker runs as **uid 1000**, so it is unwritable —
      *and* you must not, because anything under `/blueprints` is picked up by the **discovery scan and
      applied for real.**
      **Working route (verified live, authentik 2026.8.2):** `kubectl cp` the file to `/tmp` on the worker, then
      ```
      kubectl -n kube-auth exec deploy/authentik-worker -- ak shell -c \
        "from authentik.blueprints.v1.importer import Importer; \
         i = Importer.from_string(open('/tmp/forgejo.yaml').read()); print(i.validate())"
      ```
      `.apply()` for a real scratch apply (`forgejo-oidc-test`). **This also removes the old cost:** no chart
      update, no `extra_blueprints`, no live worker roll.
      **⚠️ `validate()` is NOT free (Pass 24).** It is `_apply_models()` wrapped in `transaction_rollback()` +
      `capture_logs()` (`blueprints/v1/importer.py:453-467`) — it **really executes the apply** and then rolls
      it back. Two consequences: (a) it takes **row locks on the live DB**, so don't run it concurrently with
      the worker's own scan; (b) `apply_blueprint` calls `validate()` with `raise_validation_errors=False`, so
      **`VALID: True` covers everything, but `VALID: False` tells you only about the *earliest* error.**
      **Teardown (Pass 24):** a `state: absent` file must reference its targets with **`!Find`, never `!KeyOf`**
      — `KeyOf.resolve` **raises `EntryInvalidError`** when its target has no instance
      (`blueprints/v1/common.py:239-252`), and in a teardown the targets are precisely the objects being
      deleted. `!Find` fails open → `None` → matches nothing → the entry is skipped safely. Order:
      bindings → application → provider → scope mappings → groups → certificatekeypair; and delete the scratch
      `BlueprintInstance` row too if the file was ever discoverable.
- [x] T1.6 **⛔ GATE — idempotency, asserted on the ONE silent field (Pass 24).** Re-running the blueprint
      must not duplicate objects — **and the assertion must target `signing_key_id`**, because that is the
      *only* failure in the set that fails **silently**: a `!Find` miss on a **nullable scalar FK** serializes
      as `None` with no complaint (provider adopts with `signing_key=None`, `apply_ok=True`). A `!Find` miss
      inside a **list** (`property_mappings`) is **loud** — the serializer rejects it
      (`Invalid pk "None" - object does not exist.`) and the whole blueprint is refused, atomically.
      So: re-apply, then assert the provider's `signing_key_id` is **unchanged and non-null**, plus the
      identity set (app/provider/group pks) is byte-identical.
- [x] T1.7 **Fidelity (R8):** copy the **values** of `grant_types`, token validities, redirect URIs and all
      `property_mappings` from `oidc_provider/auth.tf` — but emit the model field **`redirect_uris`**, NOT
      `allowed_redirect_uris` (the terraform attr name). **`auth.tf` is NOT the source for ~6 fields** —
      `sub_mode`, `issuer_mode`, `include_claims_in_id_token`, `logout_method`, `access_code_validity`,
      `refresh_token_threshold` are provider *defaults*, visible only in the live
      `.tmp/authentik-export.yaml` (§9). Diff the result against **§9's fidelity list + the live export** —
      **not §10** (Pass 23: §10 is an *identity/UUID* baseline, not a field baseline) — then adopt, don't recreate.
      **Framing correction (A16-6):** the OIDC config is **NOT** in `app.ini` — it is a DB `login_source`
      row, re-synced by the chart's init container on every pod start. R8's byte-match guards *that row*
      (and the chart emits its flags in Go-template sorted-key order, so the row is a pure function of the
      value set) — guard the row, not `app.ini`.
- [x] T1.8 **Q6/Q7/Q8 answered** (plan §9): preset `client_secret` honoured; built-ins via `!Find` on
      `managed`; provider adopted by `identifiers: {name: forgejo}`
- [x] T1.9 **Q9 answered**: let the `tls_*` signing pair regenerate (blueprint carries the PEMs anyway)

---

## Phase 2 — authentik core accepts extra blueprints

- [x] T2.1 Add `variable "extra_blueprints" { default = [] }` to `modules/auth/authentik/core`
- [x] T2.2 `local.helm_values.blueprints.secrets = concat([<own>], var.extra_blueprints)`
- [x] T2.3 **⛔ GATE:** `tofu validate` core; confirm no diff when `extra_blueprints = []`

---

## Phase 3 — Module split

> **⏸️ Partly PARKED 2026-10-13 (DEF-15).** **T3.3 / T3.6 / T3.7 are deferred** (the whole `forgejo/mantle`
> half + the repo list) per the owner. **The split tasks — T3.1, T3.2, T3.4, T3.5 — are NOT parked** and are
> still required for Phase 5. **T3.1/T3.2/T3.5 are DONE** (Pass 25); **T3.4 is blocked** on T4.4, so the flat
> `modules/devops/forgejo/` and `forgejo/core/` must coexist for now — the very thing T3.4 forbids.
> **⚠️ Corrected in Pass 25:** the old claim here — *"nothing in Phases 1/2/4/5 depends on the parked work"* —
> is **false**. **Phase 4 contains the mantle half** (T4.4/T4.5/T4.6/T4.7 rewire `stacks/mantle/forgejo.tf`
> onto `forgejo/mantle`) and **Phase 5's C7c requires mantle to have stopped declaring `module.forgejo`**.
> So the parked work gates the surgery. See DEF-15.
> **Prerequisite (Pass 25):** Phase 4 sources `../../modules/devops/forgejo/core`, which **T3.1 creates** —
> so T3.1/T3.2 must land before any T4.x wiring, or `tofu validate` fails with *"Module not installed"*.

- [x] T3.1 Create `modules/devops/forgejo/core/`: `namespace`, `helm`, `storage`, `listener`, `ingress`,
      `egress`, `backup`, `locals`, `outputs`, `providers`, `variables`.
      **Exact symbol triage — do NOT hand-wave "minus `oidc_*`" (N2/B). Every line below is a real
      reference; a literal reading of "delete the OIDC bits" breaks the build or silently changes
      `app.ini`:**
      - **DELETE:** `auth.tf` (whole file); `local.oidc_issuer`; `variable "oidc_issuer_base"`;
        `outputs.{client_id,admin_group_id,user_group_id}`; the `module.oidc` entry in `helm.tf`'s
        `depends_on` (N1 — `[module.bucket, module.s3_user, module.oidc]`); and **`authentik` from
        `providers.tf`'s `required_providers`** (B5 — otherwise a dead provider lingers).
      - **REWRITE (the kept `gitea.oauth` block, `locals.tf:83-93`):** `key`/`secret` (B3) and
        `autoDiscoverUrl` (**B4** — it reads the *deleted* `local.oidc_issuer`) come from the `oidc`
        input; `adminGroup`/`restrictedGroup` (B2) take the input's `admin_group`/`restricted_group`
        **or** keep deriving `${var.name}-admin`/`-user` — **decide, or the new input keys have no
        consumer.**
      - **KEEP (do NOT touch):** `local.oidc_source_name = "authentik"` (names the OAuth source; N2);
        **`variable "auth_gateway_name"`** (**B1** — its comment lies: it feeds the `egress_gateway` peer
        at `egress.tf:22`, which carries **S3 as well as authentik**; delete it and validate dies) —
        **and fix that stale comment while you are there.**
      - **STRUCTURE (C1, load-bearing):** copy the submodule **labels** verbatim (`bucket`, `s3_user`,
        `expose`→`listener_set`/`http_route`, `ingress`, `egress*`, `backup`); keep
        `backend_name = local.http_service_name` (empty ⇒ `http_route[0]` vanishes ⇒ terraform **destroys
        the git HTTPRoute**); and keep `namespace`/`name` defaults identical.
      - **PATHS (Pass 25): every `source = "../../…"` gains one `../`.** `forgejo/core/` sits one directory
        deeper than the flat module, so **all eight** submodule sources deepen to `../../../…`. Copying the
        structure verbatim without this fails `tofu validate` with eight *"Module not installed"* errors —
        which is exactly how it was found. (Not mentioned in the STRUCTURE list above; it is now.)
- [x] T3.2 `forgejo/core`: replace the module's OIDC references with an **input** `oidc`, keys exactly
      `{client_id, client_secret, discovery_url, scopes, group_claim, admin_group, restricted_group}` —
      **values in §4** (a wrong `scopes`/`group_claim` = silent R8 break).
      **⛔ ADD `validation` blocks (F17-1/F17-2/F17-5).** The input is a free-form object, so a typed-but-wrong
      value is accepted and **silently disables auth**. `scopes` goes verbatim to Forgejo's `--scopes`, which
      is a **comma-split `StringSliceFlag`**: `"openid email profile groups"` (spaces), `""`, or any list
      without `groups` **validates and drops the groups scope → nobody is admin, no error.** Validate:
      comma-separated, non-empty, contains `openid` **and** `groups`. Validate `admin_group`/
      `restricted_group` are non-empty **and equal the names the blueprint creates** — that link is
      currently two independent hand-written strings (F17-2/F17-3), so make it structural or validate it.
- [ ] T3.3 ⏸️ **PARKED 2026-10-13 (DEF-15).** Create `modules/devops/forgejo/mantle/` = `harbor_robot_account` +
      `forgejo_repository_action_secret` (names `HARBOR_USER` / `HARBOR_TOKEN`), `variables`, `outputs`,
      `providers`.
      **⛔ Pass 18 (G18-2): `forgejo_repository_action_secret` takes a NUMERIC `repository_id`, not
      `owner`/`name`** (provider v1.6.1 docs + source — every path calls `getRepositoryByID`). The plan never
      created the lookup. Add **`data.forgejo_repository { owner, name }`** per entry in
      `forgejo_registry_repos` and pass `.id`; a missing repo then fails at **plan** time, which is what we
      want.
      **⛔ Pass 19 (J19-1): `data.forgejo_repository` is READ-ONLY — it cannot ENABLE Actions.** Enabling the
      unit requires the **resource** `forgejo_repository { has_actions = true }`, which means **importing the
      existing repos** into state (or running a PATCH loop). Decide which: importing is declarative and gives
      drift detection; a PATCH loop is not state-tracked. Either way, gate on
      `GET /api/v1/repos/<owner>/<repo>/actions/secrets == 200`.
      **Pass 18 (G18-3): the old `depends_on = [module.harbor_setup]` rationale was wrong** — `harbor_setup`
      owns the `linuxguru` project, not `library`. `library` is Harbor's *default public* project (verified
      live: `GET /api/v2.0/projects`). Keep the edge if the robot needs it, but **fix the comment**.
      *(Verified good: `harbor_robot_account` exists in `goharbor/harbor` 3.12.5, and its `secret` is
      `Optional+Computed` — filled from the POST response — so `HARBOR_TOKEN` sources in the same apply.)*
      **⛔ Pass 20 (O20-3): `module.harbor_setup` does NOT exist at this module's scope.** It is a
      `stacks/mantle`-scope module (`stacks/mantle/devops.tf:1`), so declaring
      `depends_on = [module.harbor_setup]` **inside `forgejo/mantle/`** is the exact **E17-1 class** — a hard
      `tofu validate` error (*"reference to undeclared module"*). Either drop the edge or pass it in from the
      **stack**. (This finding was raised in the Pass-18 run, reached the raw report, and was **lost before
      folding** — hence its own callout here.)
      **⛔ Pass 20 (M20-2): the `forgejo_repository { has_actions = true }` resource is OVER-BROAD — gate it
      hard.** It "works", but the provider's `Update` builds a **full** `EditRepoOption` from **defaults**, so
      importing live repos and applying would silently force every unit (wiki/issues/PRs/releases/packages) to
      `true`, set `archived = false` (**un-archiving archived repos**), and hand `mantle` a
      **delete/archive handle on the crown jewels** — on a plan whose whole thesis is "data is sacred" (D8).
      Its import id is **`owner/name`** (not the numeric id). Prefer a **narrow, explicit PATCH per target
      repo**, or import with every flag pinned to its live value first — and scope it to
      `forgejo_registry_repos` only.
- [x] T3.8 **✅ DONE 2026-10-13 (Pass 21) — was the showstopper (G18-1).** The live `app.ini` had
      `[repository] DISABLED_REPO_UNITS = repo.actions`, set by **no `.tf` file** (stale PVC drift from a
      removed module version). Forgejo hides the actions-secrets API behind the Actions unit
      (`reqOwner(unit.TypeActions)`), so **every `forgejo_repository_action_secret` 404'd** — making the
      **goal's whole second half inert.**
      **Applied:** `gitea.config.repository.DISABLED_REPO_UNITS = ""` in `locals.tf` (carries to
      `forgejo/core` at T2/T3) → `tofu apply` **1 changed / 0 destroyed**, helm rev 5→6, clean restart.
      The line now reads `DISABLED_REPO_UNITS = ` (empty) — **present-but-empty clears it; omitting the
      key does not** (so the explicit `""` is load-bearing, not cosmetic). **`app.ini` drift is invisible
      to value-only gates — it had to be read off the pod.**
      **✅ Pass 21 (live, empirical): J19-1's "`PATCH {"has_actions":true}` is a silent no-op" is FALSIFIED.**
      The no-op holds **only while the global flag is set** — it was a *second symptom* of the same stale
      line. With the flag cleared:
      - **new** repo → `has_actions = true` **by default**, secrets route **200** (no write needed);
      - **pre-existing** repo → `has_actions = false`, **404** (no unit row — J19-1's count was right);
      - `PATCH {"has_actions":true}` → `has_actions = true`, **200** ✅
      So the fix **is** sufficient given a **per-repo write for the pre-existing repos** (T3.3) — the
      plan's *preferred* narrow-PATCH route works, so the over-broad `forgejo_repository` **import is
      avoidable** (G18-3/O20-2). Gate: `GET /api/v1/repos/<owner>/<repo>/actions/secrets` → **200**.
      Probe repo left in place: `breakglass/actions-probe` (private, disposable).
- [ ] T3.6 ⏸️ **PARKED 2026-10-13 (DEF-15).** **Decide the repo list** for `forgejo_registry_repos` (owner/name) — the plan does not name
      them. Default `[]` means **no secrets are created** and V-E4 cannot pass.
- [ ] T3.7 ⏸️ **PARKED 2026-10-13 (DEF-15).** **Declare `forgejo_registry_repos`** in `stacks/mantle/variables.tf` and thread it into the
      module (it was in the parked prototype; currently unowned).
- [ ] T3.4 `git rm` the superseded old `modules/devops/forgejo/*.tf` — do NOT leave both
      **Unblocked by the T4.4 decision** (drop, not repoint): do this **after** T4.4 removes the module from
      mantle, so nothing sources the flat path any more. Until then the flat module and `forgejo/core/` must
      coexist — the very thing this task forbids — because Phase 4's wiring is in flight.
- [x] T3.5 **⛔ GATE:** `tofu fmt` clean on every new/changed file

---

## Phase 4 — Stack wiring

- [ ] T4.1 `stacks/core`: `module "forgejo"` → `../../modules/devops/forgejo/core` with `domain`,
      `cert_issuer`, `host_network`, and an **explicit** `oidc` object (N3 — `module.forgejo_oidc.*` can't
      satisfy the input, since `scopes`/`group_claim`/the group names are stack literals, not module
      outputs):
      **⛔ NO `count` / `for_each` on this module** (**C1** — `harbor`/`argo` use `count`, but doing it here
      shifts every address to `module.forgejo[0]…` and terraform **destroys the namespace**).
      **⛔ ADD `depends_on` for the producers it used to inherit for free (C16-9).** In `mantle` these were
      ordered by cross-stack sequencing; inside `core` they are same-stack and **unguarded**, because the
      module reaches them through *defaulted string literals*, not module references:
      `depends_on = [module.seaweedfs, module.storage, module.network]` — the `bucket`/`s3_user` submodules
      `kubectl exec` into SeaweedFS (`stacks/core/storage.tf:1`); **`module.storage`** owns Velero (its
      `module "backup"` lives at `modules/storage/backup.tf:1`, and core's own analogue does exactly this
      at `modules/storage/backup.tf:31`); and `expose`/`egress` default to the `private` gateway, which
      `module.network` creates.
      **Also (K19-2):** prefer **sourcing** the gateway name (`expose`/`egress` currently use a hardcoded
      `default = "private"` literal) from `module.network.gateway_name`/`gateway_namespace` — that restores
      a real dependency edge instead of papering over it with `depends_on`.
      **⚠️ Pass 17 correction (E17-1): `module.backup` does NOT exist at stack scope.** `core` declares
      only `network`, `storage`, `cert_man`, `authentik`, `harbor`, `argo`, `seaweedfs`, … The Pass-16 edit
      copied `depends_on = [module.backup]` from a *module-internal* file into *stack* scope, where it is a
      hard `tofu validate` error (**"reference to undeclared module"**). Use **`module.storage`**.
      `oidc = { client_id = module.forgejo_oidc.client_id, client_secret = module.forgejo_oidc.client_secret,`
      `discovery_url = module.forgejo_oidc.discovery_url, scopes = "openid,email,profile,groups",`
      `group_claim = "groups", admin_group = "forgejo-admin", restricted_group = "forgejo-user" }`
- [ ] T4.2 `stacks/core`: `module "forgejo_oidc"` → `../../modules/auth/authentik/oidc_blueprint`
      **with the input contract spelled out** (Pass 23 — it was never specified anywhere, O20-1 class):
      `name = "forgejo"` (load-bearing, D3/A16-4), **`issuer_base = var.deployment.auth.server`** (the direct
      replacement for the deleted `oidc_issuer_base` — the *only* thing `discovery_url` can be built from),
      `domain` (for the two redirect URIs), and **`namespace`** (Pass 24 — it was missing here while T4.10
      already required it for the Secret's destination, `kube-auth`). Consumes the module's four outputs (§4).
- [ ] T4.3 `stacks/core`: `module "authentik"` gains `extra_blueprints = [module.forgejo_oidc.blueprint_secret]`
- [ ] T4.4 **`stacks/mantle/forgejo.tf`: DROP `module "forgejo"` entirely — do NOT repoint it.** *(Owner
      decision 2026-10-13, "use your best judgement"; this supersedes the task's original "repoint to
      `forgejo/mantle`" wording.)*
      **Rationale:** the Harbor→Actions half is parked (DEF-15), and after **T4.5** (`data.authentik_group`)
      and **T4.6** (literals) **nothing in `mantle` needs a Forgejo module at all** — verified: only
      `admins.tf`, `users.tf` and `forgejo.tf` reference `module.forgejo`, and all three are covered by
      T4.5/T4.6. So the clean end state is that mantle simply stops declaring it.
      **⛔ ORDER IS LOAD-BEARING (C7c):** edit the config **and move the state in the same sitting — never
      `apply` in between.** Config-without-the-module + state *still holding* the 18 entries = a plan that
      **destroys the namespace.** The state move (Phase 5) is what turns that plan into a no-op.
      **If the CI half is ever unparked:** the repoint variant returns — `module "forgejo_setup"` sourcing
      `../../modules/devops/forgejo/mantle`, named like `harbor_setup`/`argo_setup` (avoids two modules
      called `forgejo` colliding with `forgejo_runner`). It is **purely additive**: no rework of anything
      built above, which is why dropping now costs nothing.
- [ ] T4.5 `stacks/mantle/admins.tf` + `users.tf`: `module.forgejo.{admin,user}_group_id` →
      `data.authentik_group.forgejo_{admin,user}.id` (new `data "authentik_group"` blocks in
      `stacks/mantle/forgejo.tf` — the repo's first use of that data source). Comment carries C16-6 (the
      groups are created by the **async** worker, so a plan that beats it fails).
      **⛔ Pass 27 — GATE (silent-failure risk): after this swap, `authentik_group.admin` and
      `authentik_group.user` must plan NO-OP. Any update = STOP.** Reason, verified: those umbrella groups'
      `parents` **hardcode the forgejo pks** — `admin` carries `e99a0ce2…` (= `forgejo-admin`), `user`
      carries `0e04476d…` (= `forgejo-user`). The swap changes the *provenance* of that id from a managed
      resource's output to a **read of the live group**; if the data source returned anything but the pk,
      the umbrella groups would **re-nest and everyone would lose admin — silently.** This is the A16-4
      failure shape, one layer over.
- [ ] T4.6 `stacks/mantle/forgejo.tf`: runner `instance_url`/`namespace`/`secret` → literals
      (`https://git.<domain>`, `devops-forgejo`, `forgejo-admin`)
- [ ] T4.7 `stacks/mantle`: add **`svalabs/forgejo` 1.6.1** (pinned) to `required_providers`, plus a
      `provider "forgejo"` block — `host = https://git.<domain>` and `username`/`password` from a new
      **`data.kubernetes_secret_v1`** on the chart-minted `forgejo-admin` Secret (house pattern; no new
      credential). **← M1: this wiring was previously missing.**
- [x] T4.8 **⛔ GATE:** `tofu validate` both stacks — ✅ ran clean (Pass 25).
      **⚠️ Pass 25 — `validate` is NECESSARY BUT NOT SUFFICIENT for the `oidc` input.** OpenTofu does **not**
      evaluate *cross-variable* `validation` conditions at validate time; only self-referencing ones fail
      there. Empirically: the four conditions referencing only their own variable failed at `validate`,
      while `admin_group == "${var.name}-admin"` **passed validate and failed only at plan** (*Invalid value
      for variable*). So T4.8 covers **half** the input — **run a `tofu plan`** to exercise the rest.
- [ ] T4.9 `stacks/core/providers.tf`: add **`tls` 4.4.1** (matches mantle) to `required_providers` — the
      `oidc_blueprint` needs it
- [ ] T4.10 `oidc_blueprint` writes its Secret into **`kube-auth`**; add `namespace` input +
      `depends_on` the namespace resource

---

## Phase 5 — State surgery  ⛔ HIGH-RISK

> **⛔ PREREQUISITE (C7c).** Phases 3 **and** 4 must be fully landed and `tofu validate` must pass in both
> stacks **before** any state push. Push the moved state into `core` before `module "forgejo"` exists
> there and `tofu plan` will **destroy the namespace**. Equally, `mantle` must have stopped declaring
> `module.forgejo` before its new state lands.
> **Also (C4):** the move script's dependency audit reads a `dependencies` field that is **empty in these
> states** — treat its "(none)" as informational, not as verification of anything.
> **✅ Pass 27 — PROVE the hazard, don't just warn about it (Flag C).** The runbook jumped from the config
> edit straight to the push, so the dangerous window is never *seen*. Demonstrate it, in order:
> 1. **(post-T4.4, pre-push)** `tofu plan` mantle → expect **18 destroys, including
>    `kubernetes_namespace_v1.namespace`.** ← that *is* the hazard, on screen.
> 2. `state push mantle-moved-<TS>` → then `tofu state list | grep -E '^module\.forgejo(\.|$)'` must be
>    **empty** (and `module.forgejo_runner` must still be there).
> 3. `state push core-moved-<TS>`.
> 4. `tofu plan` mantle → **0 destroys**. `tofu plan` core → **4 adds** (`forgejo_oidc`) + **2 updates**
>    (`module.forgejo.helm_release.forgejo` for the client_secret, `module.authentik.helm_release.helm` for
>    the blueprint Secret) + **0 destroys**.
> **Push order: mantle first, then core** — the mirror of the rollback order. Removing from mantle first
> kills the destroy path before core gains the objects.
> **⚠️ Cross-check the candidates against the plan (Pass 27):** assert `mantle-moved-<TS>`'s `module.forgejo*`
> set is **address-identical** to core's plan's `module.forgejo.*` set — 17/17, 0 orphans, 0 fresh creates.
> That makes T0.7's re-verification mechanical. **And note the 18 = 17 managed + 1 `data` cache**
> (`…module.ingress.data.kubernetes_nodes.all`).

- [ ] T5.0 **Helm-values pre-gate (M3).** *Before any config edit*, capture the current rendered values:
      `helm -n devops-forgejo get values forgejo -o yaml > /tmp/forgejo-values-before.yaml`. After the
      split, confirm the plan's `helm_release.forgejo` update touches **only** the OAuth `client_secret` —
      **not** `domain`, `ROOT_URL`, `autoDiscoverUrl`, redirects, scopes, or `groupClaimName`. The OIDC
      block is being re-plumbed (`local.oidc_issuer` → an `oidc` input); a stray value change restarts
      Forgejo with a broken `app.ini`. **T5.7 cannot be trusted without this.**
      **⚠️ Pass 25 — this gate CANNOT be run by reading a plan.** The plan reports
      `after_unknown.values = [true]` for `module.forgejo.helm_release.forgejo` (verified on the saved
      plan): the chart values are unknown because `client_secret` comes from a `random_password` created in
      the **same** apply. So "confirm the plan's update touches only the `client_secret`" is
      **unsatisfiable**. **Substitute — and it works:** render `forgejo/core` through a **scratch root** with
      a literal `client_secret`, then diff that against `helm get values`. Harness kept at
      `.tmp/forgejo-core-render/`; the comparison came back **DIFF EMPTY** apart from the secret. **That
      scratch-render diff IS the gate** — not an aside.

Exact commands (single operator; `TOFU` = `tofu` from each stack dir):

```bash
cd /Users/jblack/code/k8s/terraform
ROOT=$PWD            # capture BEFORE any cd (subshells must not skew it)
TS=$(date +%Y%m%d-%H%M%S)

# 0. fresh backups, before anything
( cd stacks/core   && tofu state pull > "$ROOT/.tmp/backups/core-$TS.tfstate" )
( cd stacks/mantle && tofu state pull > "$ROOT/.tmp/backups/mantle-$TS.tfstate" )
echo "$TS" > "$ROOT/.tmp/backups/.last-ts"

# 1. init both stacks (picks up new modules + the forgejo provider)
( cd stacks/core   && tofu init )
( cd stacks/mantle && tofu init )

# 2. DRY-RUN the move — writes candidates only, never pushes (pass the TS explicitly)
python3 "$ROOT/.tmp/forgejo-split-move.py" "$TS"

# 3. PUSH — mantle FIRST (drops its module.forgejo), verify it is gone, THEN core (adopts them).
#    The two backends have NO transaction: between pushes both states could claim the same objects,
#    so this order leaves an authz-gap at worst, not a double-ownership window.
( cd stacks/mantle && tofu state push "$ROOT/.tmp/backups/mantle-moved-$TS.tfstate" )
( cd stacks/mantle && tofu state list | grep -E '^module\.forgejo(\.|$)' && echo 'ABORT: mantle still owns forgejo' || echo 'ok: mantle clean' )
( cd stacks/core   && tofu state push "$ROOT/.tmp/backups/core-moved-$TS.tfstate" )

# 4. GATES
( cd stacks/core   && tofu plan )    # expect 0 destroy
( cd stacks/mantle && tofu plan )    # expect 0 destroy
```

- [ ] T5.1 Re-take state backups (T0.7); record timestamps
- [ ] T5.2 `tofu init` (or `init -upgrade`) both stacks to pick up modules/providers
- [ ] T5.3 Pull both states fresh; script the move: every `module.forgejo.*` entry **except**
      `module.forgejo.module.oidc.*` is cut from mantle JSON and pasted into core JSON verbatim
- [ ] T5.4 Move **whole `child_modules`**, not just leaf resources: `bucket`, `expose`, `ingress`,
      `egress`, `egress_gateway`, `egress_internet`, `backup`, `s3_user`
- [ ] T5.5 `tofu state push` **both** candidate states (`core-moved-$TS`, `mantle-moved-$TS`). The script
      already pruned mantle (moved → core; oidc → **dropped = forgotten**), so there is **no `state rm`**
- [ ] T5.6 Confirm the pushed **mantle** state holds **no `module.forgejo` entries at all** (moved *and*
      oidc gone) — the oidc is **forgotten, not destroyed** (D4). Verify with
      `tofu state list | grep -E '^module\.forgejo(\.|$)'`.
      **⚠️ Pass 18 (I18-1): the old pattern `grep '^module\.forgejo'` is a PREFIX match — it ALSO matches
      `module.forgejo_runner`, which legitimately stays in mantle. So the guard fired on *every correct
      push*.** The `(\.|$)` bound is what makes it exact.
- [ ] T5.7 **⛔ GATE:** `tofu plan` **core** → **0 destroys** (hard). Enumerate the expected non-destroy
      changes and confirm each: adds from `module.forgejo_oidc` (blueprint Secret, `random_password`, tls
      key+cert) and **exactly TWO updates** (**C16-8**): `helm_release.forgejo` (the new `client_secret`)
      **and** `module.authentik.helm_release.helm` — `extra_blueprints` mutates the `blueprints.secrets`
      helm value, so the authentik release *will* re-render. That second update is **expected; do NOT STOP
      on it.** **Anything else = STOP.**
- [ ] T5.8 **⛔ GATE:** `tofu plan` **mantle** → instance gone with **0 destroys** (**especially none on the
      namespace or the bucket** — D8); CI module adds robot/secrets
- [ ] T5.9 Verify backups still intact before proceeding
- [ ] T5.10 Confirm the `expose`/`listener_set` **`kubernetes_manifest`** resources moved with **no diff**
      (they re-read live objects on plan)

> **⚠️ Pass 18 (I18-3, I18-4) — two resumption traps:**
> 1. **Never re-pull state mid-surgery.** If you stop after the mantle push but before the core push, the
>    objects sit in *neither* state. Re-running T5.1 would re-pull with a **new `$TS`**; the script would
>    then compute **0 moves**, the core push would no-op, and the namespace would be **silently orphaned** —
>    a later `tofu apply core` would try to *create* an already-existing namespace. **Resume by pushing the
>    `*-moved-$TS.tfstate` files already produced**, not by re-running the script.
> 2. **The move script is NOT in git.** `.tmp/` is gitignored, so `forgejo-split-move.py` lives only on the
>    author's machine (`git ls-files | grep -c '.tmp/'` → 0). **Copy it somewhere durable (or commit it)
>    before Phase 5** — it is the artefact the surgery *executes*.

---

## Phase 6 — Apply

- [ ] T6.0 **Take fresh OFF-CLUSTER backups immediately before applying** (D8/D9). The Velero backup has
      a **720h ttl** (Pass 20, O20-4 — the docs previously said "168h", which is the *schedule's* ttl) and is
      not the only copy any more — but take all of these, in this order:
      - `forgejo dump` → `/Users/jblack/backups/forgejo/dump/` (git + SQLite DB + config)
      - `aws s3 sync s3://forgejo/` → `/Users/jblack/backups/forgejo/s3/` (LFS/attachments/avatars/artifacts)
      - `tofu state pull` (both stacks) → `/Users/jblack/backups/forgejo/tfstate/`
      - a fresh Velero backup too
      - exact commands: `/Users/jblack/backups/forgejo/README.md`
- [ ] T6.1 **⛔ GATE — the DATA-LOSS gate (D8):** re-read both plans. **ABORT on ANY destroy of
      `kubernetes_namespace_v1.namespace` or `module.bucket.*`** — those are the only irrecoverable ones.
      A `helm_release.forgejo` destroy is survivable (its PVC carries `keep`) = disruption, not data loss.
- [ ] T6.2 `tofu apply` **core** (creates blueprint secret, updates authentik, adopts the release)
- [ ] T6.3 Verify authentik applied the blueprint (worker log; app appears in authentik)
- [ ] T6.3b Confirm the **worker** (not just server) rolled out — blueprints mount on the worker only (R10)
- [ ] T6.3c **⛔ GATE (C16-6):** confirm BOTH `forgejo-admin` and `forgejo-user` exist in authentik **before
      planning `mantle`** — they are created by the async worker (start-up or the 60-min scan), and
      `mantle`'s `data.authentik_group` (D3) fails if it beats the worker. Verify:
      `kubectl -n kube-auth exec deploy/authentik-worker -- ak shell -c 'from authentik.core.models import Group; print([g.name for g in Group.objects.all()])'`
      Check membership too: the `admin`/`user` umbrella groups in `mantle` nest these, so a missing/renamed
      group silently drops everyone's rights.
- [ ] T6.4 `tofu apply` **mantle** (creates robot + repo secrets; re-syncs admins/users groups)
- [ ] T6.5 `tofu plan` both → **No changes** (idempotency)
- [ ] T6.6 Verify **other apps still log in** after the apply (V-C10) — the worker roll shouldn't affect
      login, but confirm rather than assume (R12).
      **⚠️ Pass 24 — the D6 rotation race is documented backwards, and this is where to check it.** R7/R9 frame
      it as "Forgejo points at a provider that doesn't exist". The real race is the **mirror image**: the *new*
      `client_secret` reaches the provider via the **worker** (chart rollout, or up to the 60-min scan), while
      the *old* one leaves the Forgejo **init-container `login_source` re-sync at pod start**. Whichever wins,
      the two disagree — and the token endpoint rejects while **the login page still renders** (E17-4's silent
      shape, on the *normal* path). Accepted per D8, but verify it rather than assume: one `ak shell` line
      comparing `OAuth2Provider.objects.get(name='forgejo').client_secret` against the live `login_source` row.

---

## Phase 7 — Land it

- [ ] T7.1 Run the VALIDATION checklist end to end
- [ ] T7.2 Commit (one per logical step, or squashed with a detailed body)
- [ ] T7.3 Update memory (`forgejo`, `forgejo-runner`, new `forgejo-split`); prune stale notes
- [ ] T7.4 Re-file deferred items (see `FORGEJO-SPLIT-DEFERRED.md`)

---

## Decision gates summary (all must pass in order)

1. **T1.5** blueprint applies cleanly on a scratch app
2. **T1.7** fidelity — `redirect_uris` (not `allowed_redirect_uris`)
3. **T2.3** core validates with empty `extra_blueprints`
4. **T3.5** fmt clean; ~~**T3.6** repo list decided~~ ⏸️ **parked (DEF-15)**; **T3.8** ✅ the Actions repo-unit is enabled —
   `DISABLED_REPO_UNITS = ""` **applied & verified live** (Pass 21). ⏸️ The per-repo PATCH (T3.3) and the
   Harbor→Actions path (V-E4) are **parked (DEF-15)** — the split does not depend on them.
5. **T4.8** both stacks validate
6. **T5.7 / T5.8** both plans show **0 destroys** on protected objects (T5.7 also enumerates expected adds/update)
7. **T6.0** fresh **DR set** taken — `forgejo dump` + `aws s3 sync` + state pulls + Velero
8. **T6.1** final read-through before any apply

