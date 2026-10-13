# Forgejo core/mantle split — WORK CHECKLIST

Legend: `[ ]` todo · `[x]` done · `[~]` in progress · `[!]` blocked · `[?]` decision needed
Gate marker: **⛔ GATE** = do not proceed until the stated check passes.

---

## Phase 0 — Safety (DONE)

- [x] T0.1 `tofu state pull` both stacks → `.tmp/backups/{core,mantle}-<ts>.tfstate`
- [x] T0.2 Dump backend Secrets → `.tmp/backups/{core,mantle}-secret-<ts>.yaml`
- [x] T0.3 Validate both state files parse (jq); count resources (189 / 477)
- [x] T0.4 Commit pending work; tree clean (`4513f9c`)
- [x] T0.5 Gitignore `.tmp/` (state backups live there)
- [x] T0.6 Velero backup `forgejo-pre-split` → **Completed 54/54**, PVB 8.33 GB
- [ ] T0.7 Re-take backups **immediately before** Phase 5 (states will have drifted)
- [x] T0.8 Capture pre-change authentik UUID baseline → plan §10 (done)

---

## Phase 1 — Forgejo OIDC blueprint module (build + verify in isolation)

- [ ] T1.1 Enumerate the objects `modules/auth/authentik/oidc_provider/auth.tf` creates (done: 192 lines)
- [ ] T1.2 Blueprint schema **now pinned** (plan §9): model names, identifiers, `!Find`/`!KeyOf`, and the
      atomic-apply + 60-min discovery behaviour
- [ ] T1.2b **Use the live export as the template:**
      `kubectl -n kube-auth exec deploy/authentik-worker -- ak export_blueprint > .tmp/authentik-export.yaml`
      then copy-and-trim the Forgejo provider/application/mappings/bindings (already saved at
      `.tmp/authentik-export.yaml`)
- [ ] T1.3 Create `modules/auth/authentik/oidc_blueprint/` (variables, providers, locals,
      `blueprint.tftpl`, main, outputs)
- [ ] T1.4 Reproduce: `forgejo-admin`/`forgejo-user` groups; `groups` + `profile` scope mappings
      (custom expressions); signing cert/key pair (PEMs from `tls_*`); oauth2 provider (client_id = app
      slug, client_secret from `random_password`, built-in flows via `!Find`, property mappings,
      `redirect_uris` *(the model field — do **not** emit `allowed_redirect_uris`, the terraform attr name)*,
      `grant_types`); application; policy bindings for both groups
- [ ] T1.5 **⛔ GATE:** apply the blueprint under a scratch name (`forgejo-oidc-test`); confirm the
      worker logs `applied` and the app appears in authentik; then remove the scratch blueprint + objects
- [ ] T1.5b ~~verify no-rollout delivery~~ **RETIRED** — D7 now extends `blueprints.secrets`; the worker
      roll is harmless (login unaffected)
- [ ] T1.6 Confirm idempotency: re-running the blueprint does not duplicate objects
- [ ] T1.7 **Fidelity (R8):** copy the **values** of `grant_types`, token validities, redirect URIs and all
      `property_mappings` from `oidc_provider/auth.tf` — but emit the model field **`redirect_uris`**, NOT
      `allowed_redirect_uris` (the terraform attr name). Diff the result against plan §10 (adopt, don't recreate).
- [ ] T1.8 **Q6/Q7/Q8 answered** (plan §9): preset `client_secret` honoured; built-ins via `!Find` on
      `managed`; provider adopted by `identifiers: {name: forgejo}`
- [ ] T1.9 **Q9 answered**: let the `tls_*` signing pair regenerate (blueprint carries the PEMs anyway)

---

## Phase 2 — authentik core accepts extra blueprints

- [ ] T2.1 Add `variable "extra_blueprints" { default = [] }` to `modules/auth/authentik/core`
- [ ] T2.2 `local.helm_values.blueprints.secrets = concat([<own>], var.extra_blueprints)`
- [ ] T2.3 **⛔ GATE:** `tofu validate` core; confirm no diff when `extra_blueprints = []`

---

## Phase 3 — Module split

- [ ] T3.1 Create `modules/devops/forgejo/core/`: `namespace`, `helm`, `storage`, `listener`,
      `ingress`, `egress`, `backup`, `locals` (minus oidc_*), `outputs` (fqdn/name/namespace/ssh_fqdn),
      `providers` (helm/kubernetes/kubectl), `variables`
- [ ] T3.2 `forgejo/core`: replace `module "oidc"` with an **input** `oidc = { client_id, client_secret,
      discovery_url, scopes, group_claim, admin_group, restricted_group }`
- [ ] T3.3 Create `modules/devops/forgejo/mantle/` = `harbor_robot_account` +
      `forgejo_repository_action_secret` (+ org variant per Q3), `variables`, `outputs`, `providers`
- [ ] T3.6 **Decide the repo list** for `forgejo_registry_repos` (owner/name) — the plan does not name
      them. Default `[]` means **no secrets are created** and V-E4 cannot pass.
- [ ] T3.4 `git rm` the superseded old `modules/devops/forgejo/*.tf` — do NOT leave both
- [ ] T3.5 **⛔ GATE:** `tofu fmt` clean on every new/changed file

---

## Phase 4 — Stack wiring

- [ ] T4.1 `stacks/core`: `module "forgejo"` → `../../modules/devops/forgejo/core` with `domain`,
      `cert_issuer`, `host_network`, `oidc = module.forgejo_oidc.*`
- [ ] T4.2 `stacks/core`: `module "forgejo_oidc"` → `../../modules/auth/authentik/oidc_blueprint`
- [ ] T4.3 `stacks/core`: `module "authentik"` gains `extra_blueprints = [module.forgejo_oidc.blueprint_secret]`
- [ ] T4.4 `stacks/mantle/forgejo.tf`: repoint the CI module and **name it `forgejo_setup`** (sourcing
      `../../modules/devops/forgejo/mantle`) — matches `harbor_setup`/`argo_setup`, and avoids two
      different modules both called `forgejo` (whose prefixes collide with `forgejo_runner`)
- [ ] T4.5 `stacks/mantle/admins.tf` + `users.tf`: `module.forgejo.{admin,user}_group_id` →
      `data.authentik_group.forgejo_{admin,user}.id`
- [ ] T4.6 `stacks/mantle/forgejo.tf`: runner `instance_url`/`namespace`/`secret` → literals
      (`https://git.<domain>`, `devops-forgejo`, `forgejo-admin`)
- [ ] T4.7 `stacks/mantle`: add `svalabs/forgejo` to `required_providers` + `provider "forgejo"`
- [ ] T4.8 **⛔ GATE:** `tofu validate` both stacks
- [ ] T4.9 `stacks/core/providers.tf`: add **`tls`** to `required_providers` (the `oidc_blueprint` needs it)
- [ ] T4.10 `oidc_blueprint` writes its Secret into **`kube-auth`**; add `namespace` input +
      `depends_on` the namespace resource
- [ ] T4.11 Serialize: `module "forgejo"` (core) `depends_on = [module.authentik]` so the helm update
      can't race the worker's blueprint apply (R9)

---

## Phase 5 — State surgery  ⛔ HIGH-RISK

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

# 3. PUSH the modified states (gated: only after T5.1-T5.4 reviewed)
( cd stacks/core   && tofu state push "$ROOT/.tmp/backups/core-moved-$TS.tfstate" )
( cd stacks/mantle && tofu state push "$ROOT/.tmp/backups/mantle-moved-$TS.tfstate" )

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
      `tofu state list | grep '^module\.forgejo'` (note the **dot** — `module.forgejo_runner` must not match)
- [ ] T5.7 **⛔ GATE:** `tofu plan` **core** → **0 destroys** (hard). Enumerate the expected non-destroy
      changes and confirm each: adds from `module.forgejo_oidc` (blueprint Secret, `random_password`, tls
      key+cert) and **exactly one update** — `helm_release.forgejo` values (the new `client_secret`).
      **Anything else = STOP.**
- [ ] T5.8 **⛔ GATE:** `tofu plan` **mantle** → instance gone with **0 destroys** (**especially none on the
      namespace or the bucket** — D8); CI module adds robot/secrets
- [ ] T5.9 Verify backups still intact before proceeding
- [ ] T5.10 Confirm the `expose`/`listener_set` **`kubernetes_manifest`** resources moved with **no diff**
      (they re-read live objects on plan)
- [x] T5.11 (waived by owner — `.tmp/` will not be wiped; the script stays there)

---

## Phase 6 — Apply

- [ ] T6.0 **Re-take the Velero backup** immediately before applying — `forgejo-pre-split` has **ttl 168h**
      and is the ONLY off-box copy (Longhorn's target is down, D-1). Do not let it expire first.
- [ ] T6.1 **⛔ GATE — the DATA-LOSS gate (D8):** re-read both plans. **ABORT on ANY destroy of
      `kubernetes_namespace_v1.namespace` or `module.bucket.*`** — those are the only irrecoverable ones.
      A `helm_release.forgejo` destroy is survivable (its PVC carries `keep`) = disruption, not data loss.
- [ ] T6.2 `tofu apply` **core** (creates blueprint secret, updates authentik, adopts the release)
- [ ] T6.3 Verify authentik applied the blueprint (worker log; app appears in authentik)
- [ ] T6.3b Confirm the **worker** (not just server) rolled out — blueprints mount on the worker only (R10)
- [ ] T6.4 `tofu apply` **mantle** (creates robot + repo secrets; re-syncs admins/users groups)
- [ ] T6.5 `tofu plan` both → **No changes** (idempotency)
- [ ] T6.6 Verify **other apps still log in** after the apply (V-C10) — the worker roll shouldn't affect
      login, but confirm rather than assume (R12)

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
4. **T3.5** fmt clean; **T3.6** repo list decided
5. **T4.8** both stacks validate
6. **T5.7 / T5.8** both plans show **0 destroys** on protected objects (T5.7 also enumerates expected adds/update)
7. **T6.0** fresh Velero backup taken
8. **T6.1** final read-through before any apply

