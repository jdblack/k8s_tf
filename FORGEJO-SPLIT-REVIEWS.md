# Forgejo core/mantle split — REVIEW LOG

One section per review pass. Findings get **folded into the core docs**
(`FORGEJO-SPLIT.md`, `-CHECKLIST.md`, `-VALIDATION.md`, `-DEFERRED.md`); this log records the *process*
and the reasoning, including things we deliberately rejected.

**Pass index:** 1 correctness · 2 completeness & risk · 3 executability · 4 adversarial premise-check ·
5 failure simulation · 6 unknowns resolved. *(6 ran before 5; sections are labelled, order on disk is
as-completed.)* **Pass 7 (minimality) was dropped** — Q10 (greenfield is a DR tenet) settled it: Option A,
the only "smaller" option, is off the table.

---

## Pass 1 — correctness ✅ (folded)

Re-verified every factual claim against the live cluster. Fixed: the Forgejo version claim (chart
`forgejo-17.2.0`, chart `appVersion` 15.0.9, image `…forgejo:16.0.5-rootless`, release rev 5); exact
stack module lists; added the PVC volumeName. Captured the **pre-change UUID baseline** (plan §10).

## Pass 2 — completeness & risk ✅ (folded)

Confirmed mechanics: blueprints mount on the **worker only**; core has **no `tls` provider**;
`expose` has no outputs; the S3 secret is `forgejo-s3`. Added risks **R8–R11**, questions **Q6–Q8**,
8 tasks, 4 validation checks.

## Pass 3 — executability ✅ (folded)

Built + dry-ran the move script (18 move / 15 forget / 444 stay; no collisions; no stale deps; all
providers present in core). Proved the DAG acyclic. Added **R12**, **Q9**, exact Phase-5 commands,
and fixed a `$PWD`-in-subshell bug in my own instructions.

---

## Pass 4 — adversarial: "should we do this at all?" ✅ (resolved by Q10)

Purpose: stop optimising how to do it, and re-test **whether** to do it.

### A1. What problem does this actually solve, *today*?

Nothing is broken. Forgejo runs; the runner is registered; OIDC works. The split fixes a
**greenfield-only** wart: mantle's `provider "forgejo"` (and its `data.forgejo_repository`) reads the
`forgejo-admin` Secret that `module.forgejo` creates **in the same stack**, so a from-scratch
`apply` of mantle would fail at plan. On the live cluster it works *because Forgejo already exists*.

### A2. Does "doing nothing" make greenfield any worse?

**No.** Mantle *already* has the identical shape — `data.external.forgejo_runner_token` shells out to
read that same `forgejo-admin` Secret, created by `module.forgejo` in the same stack. That data source
already fails on a fresh mantle apply. So adding `provider "forgejo"` introduces **no new class of
problem**. The split is therefore a **structural-tidiness refactor**, not a bug fix.

> **⚠️ SUPERSEDED.** The conclusion above is **wrong**. "Already broken" ≠ "harmless": the same-stack
> `data.external` read *is* a real greenfield break, and greenfield is a DR tenet (Q10). The split **fixes**
> a live DR-blocking bug. See the CORRECTION under Pass 4's verdict.

### A3. If the split is about consistency, is consistency worth R8–R12?

The expensive part is entirely the **blueprint** — and the blueprint exists *only* to let the instance
live in core (Forgejo's OIDC must ride the helm install). If we don't move the instance, we need no
blueprint at all. So the cost/benefit is:

| Option | Forgejo lives | OIDC mechanism | Cost | Tidy? |
|---|---|---|---|---|
| **A. Do nothing** | mantle | provider (mantle) | ~0 | ✗ (the lone exception) |
| **B. Split + blueprint** | core | blueprint (core) | **high** (new module, R8–R12) | ✓ |
| **C. Split + static authentik token** | core | provider (core) | medium | — **blocked** by the tfvars rule |
| **D. No split; provider → curl** | mantle | provider (mantle) | medium | ✗ (and less declarative) |
| **E. Split; provider-based OIDC in core** | core | provider (core) | — | blocked: token unknown at plan (greenfield) |

### A4. The decision hinge

**Do we require clean, from-scratch rebuilds?**
- **Yes** → the split is justified (it makes "core ran first" hold uniformly, like Harbor/Argo), and the
  blueprint is the only tfvars-clean way to get OIDC into core.
- **No** → **Option A** is defensible: we're paying high risk/cost for a wart that only bites on rebuilds,
  and which the runner-token source already exhibits anyway.

### A5. Does the split even *fully* fix greenfield?

Partly. Core runs first, so mantle's forgejo provider resolves. But the runner still needs Forgejo
**online and registered** — its registration + `data.external` reads the admin Secret — so a greenfield
still has ordering/staging. The split removes one wart, not the category.

### A6. What would make us abandon this?

If **Q6–Q8** (does a blueprint honour a preset `client_secret`, how to reference built-in scope
mappings, the provider's identifier field) can't be pinned down with confidence → the blueprint's
fidelity risk (R8) and silent-failure risk (R9) dominate → **Option A or D wins**.

### A7. Questions this pass puts to the owner

1. Do we genuinely need greenfield-clean rebuilds, or is the cluster effectively "pets"?
2. If it's tidiness: is the *tidiness* worth a new OIDC mechanism + a cluster-wide SSO blip?
3. Would a **one-line note** in the plan ("applied in stages; core then mantle") buy us Option A's
   benefit at zero cost?

> **Pass 4 verdict: the premise is weaker than Passes 1–3 assumed.** Recommend answering A7 before
> spending anything on Phase 1. If A7-1 is "no", stop here and take Option A.

> **⚠️ CORRECTION (after Q10 was answered).** A7-1 came back **"yes — greenfield is a DR tenet."** That
> kills Option A, and it also revealed Pass 4 was **wrong on one point**: doing nothing is *not* harmless,
> because `mantle` is **already greenfield-broken** — `data.external.forgejo_runner_token` reads a
> same-stack Secret with no fallback, so a fresh `mantle plan` fails today. The split **fixes a real
> DR-blocking bug**, so it is *necessary*, not tidiness. Pass 4's adversarial framing is retired; A1–A3
> stand as analysis, A6/A7 are resolved.

---

## Pass 6 — unknowns resolved ✅ (folded into plan §9)

Objective: stop resting on unknowns. Answered **Q1–Q9** from authentik's own repo + a **live export**:

```
kubectl -n kube-auth exec deploy/authentik-worker -- ak export_blueprint > .tmp/authentik-export.yaml
# 6682 lines: the real blueprint for every object, incl. the Forgejo provider/application/mappings
```

Sources used:
- `blueprints/system/providers-oauth2.yaml` — built-in scope mappings carry
  `identifiers: {managed: goauthentik.io/providers/oauth2/scope-<x>}`, so `!Find` by `managed` works.
- `blueprints/v1/models.mdx` — identifier semantics; **policybinding** must name exactly one of
  `policy`/`group`/`user`, and is identified by `target`(+`order`/`group`).
- `blueprints/v1/index.mdx` — blueprints are **atomic**; discovery is **file-based**, on worker start or a
  **60-minute** scan interval; `blueprints.goauthentik.io/instantiate: "false"` opts out.
- `blueprints/system/bootstrap.yaml` — `id:` + `!KeyOf` + `!Context`/`!Env` patterns.
- The **live export** — the exact Forgejo provider attrs (grant_types, validities, `redirect_uris` field
  name — *not* `allowed_redirect_uris`), the 5 property mappings, application attrs, and the fact that
  **`client_secret` round-trips** (so it can be preserved, and a preset value is honoured → Q6).

Net: **Q1–Q9 answered (plan §9)**; Q2 and Q9 got *better* answers than assumed (the secret is
preservable; the cert must be re-supplied regardless). The export also means Phase 1 is a **copy-and-trim
job, not a from-scratch authoring job** — R6's risk drops materially.

**Only Q10 remains open — and it is still the owner's call, not a research question.**

---

## Pass 5 — failure simulation ✅

Walked the real execution sequence; each step paired with a **checkable symptom** and the **exact
recovery**. Cluster facts confirmed for this pass: the blueprint volume is a **plain (non-subPath)
secret mount** at `/blueprints/mounted/secret-authentik-tfdeploykey`; rollback targets are
**authentik rev 18**, **forgejo rev 4**.

### Headline finding — **first draft was WRONG; corrected**

The first draft claimed the non-subPath mount let us dodge the worker rollout by adding a *key* to the
bootstrap Secret (**D7**, now **retired**). Two things sink it:

1. It forces core's IdP module to import **app-generated YAML** — architectural rot for a rollout it avoids.
2. **The rollout isn't even harmful.** Verified: `authentik-server` mounts **no** blueprint volume — only
   the worker does — and login is served by `authentik-server`. So a blueprint-list change rolls the
   **worker only**, which pauses **background tasks / outpost sync** but **does not interrupt login**.

**Net: D7 = extend `blueprints.secrets` with the plan's own Secret. Accept the (harmless) worker roll.**
R12 downgraded from "cluster-wide SSO blip" to "background-task pause".

### Matrix (symptom → recovery)

| Step | Half-failure | Symptom you SEE | Recovery | Dir |
|---|---|---|---|---|
| T1.5 scratch test | scratch objects linger | `forgejo-oidc-test` app/provider/groups in authentik | `state: absent` entries, or delete via UI/API | fwd |
| T1.5 blueprint typo | **atomic** → nothing created | authentik worker log error; app absent | fix `.yaml`; **no cleanup needed** | fwd |
| T2 blueprint secret | bad name/ns, or unlisted | worker pod `ContainerCreating`: "secret not found" | fix name/ns; helm update | fwd |
| T5.5 push core, mantle fails | half-moved | `core plan` = ~18 **adds**; `mantle plan` = ~18 **destroys** | **STOP.** Nothing applied yet = free. Re-push both from `.tmp/backups/*-<ts>.tfstate` | back |
| T5.5 wrong addr (module misnamed) | state orphaned | `core plan` = 18 destroy **+** 18 add | name the core module **`forgejo`**; re-push | back |
| T5.5 push rejected | serial/lineage guard | `state push` error text | `state pull` fresh → redo → or `-force` | back |
| T5 bad edit | corrupt JSON | `tofu plan` parse error | restore from `.tmp/backups/*-<ts>.tfstate` | back |
| **T6.1 any `destroy` on ns/PVC/helm** | the nightmare | `- destroy` in either plan | **DO NOT APPLY.** Restore state first | back |
| T6.2 authentik rollout hangs | SSO down cluster-wide | worker pod `Pending`/`CrashLoop` | `helm -n kube-auth rollback authentik 18` | back |
| T6.2 blueprint typo | **silent** success | terraform OK; app absent; worker log error | fix yaml, re-apply (atomic, no partial) | fwd |
| T6.2 helm `forgejo` update | secret rotated before authentik applied | Forgejo login 500 for seconds–minutes | wait; re-trigger discovery if stuck | fwd |
| T6.2 forgejo provider auth | bad creds/host | plan error (`401`) | fix provider block | fwd |
| T6.2 `data.forgejo_repository` | repo renamed/absent | plan error | fix `forgejo_registry_repos` | fwd |
| T6.2 `data.authentik_group` | groups not yet applied | plan error | ensure the blueprint landed first | fwd |
| T6.4 `s3_user` rotated | Forgejo→SeaweedFS breaks | Forgejo logs; attachments/LFS fail | re-push **mantle** from backup state (preserves `random_password`) | back |
| post | role mapping broken | SSO works but no admin role | blueprint scope fix + re-apply | fwd |
| post | runner can't register | runner pod logs | verify `forgejo-admin` + API reachability | fwd |
| post | Velero schedule gone | `kubectl -n kube-backup get schedule` | re-apply core | fwd |

### The one irreversible corner

If the **namespace** enters a destroy plan (or is deleted), the **PVC goes with it regardless of
`helm.sh/resource-policy: keep`** — namespace deletion cascades. There is **no forward path**: the only
recovery is a restore from Velero `forgejo-pre-split` (or the Longhorn snapshot… which is currently
unavailable, D-1). This is the one place where "stop and restore" is **mandatory, not optional**.

---

## Pass 8 — hostile findings ✅ (all folded)

Adversarial "asshole" read-through of all five docs. **19 defects found**; every one fixed.

### Blockers (would break the run)

1. **D7 vs Phase 2 — two mutually exclusive designs.** Fixed: **D7 retired**, Phase 2 (`extra_blueprints`
   = list of **names**) is the design. See corrected Pass 5.
2. **D7 was never designed** (adding a *key* to the bootstrap Secret needs the IdP module to import app
   YAML). Moot — D7 retired.
3. **`allowed_redirect_uris` vs `redirect_uris`.** T1.4 / T1.7 / V-C9 told you the **wrong field name**
   that §9 explicitly corrects. All three fixed to `redirect_uris` (+ a do-not-use warning).
4. **T5.5 contradicted the Phase-5 commands** (`state rm` vs push). Fixed: push both pruned states; no
   `state rm`; T5.6 rewritten to check the *pushed* state.
5. **T5.7 was unfalsifiable** ("0 add, additions excepted"). Fixed: **0 destroys** is the gate, plus an
   enumerated expected set (adds from `module.forgejo_oidc`; exactly one `helm_release.forgejo` update).

### Lies (factual errors)

6. **D-4 cited the wrong version** ("serves on 15.0.9"; deployed image is **16.0.5**). Fixed.
7. **§1/§3 described a state that isn't on disk** (provider/robot/repos are parked; module still flat).
   Added an explicit **"on disk vs planned"** note to §3.
8. **§1's "no outage beyond a re-login"** understated the **Forgejo pod restart**. Fixed.
9. **V-A3/V-A4 grepped `^module.forgejo`** — matches `module.forgejo_runner` (the exact prefix trap the
   script guards). Fixed → escaped dot + "must return nothing".
10. **"four core docs"; "D-1…D-9"** — now five, and D-1…D-11. Fixed.

### Holes

11. **Only off-box copy expires** (Velero **ttl 168h**, Longhorn down). Added **T6.0** — re-take right
    before applying.
12. **Rollback §8 omitted the authentik rollback** Pass 5 discovered. Added (`helm … rollback authentik 18`).
13. **`forgejo_registry_repos` unnamed, defaults `[]`.** Added **T3.6** to decide the list.
14. **Move script failed *quietly* on stale state** (`.last-ts`). Fixed: script now takes the timestamp as
    an argument and echoes which files it read.
15. **Two modules named `forgejo`.** Fixed: the CI module is named **`forgejo_setup`** (house pattern).
16. **Pass 5 oversold "no rollout".** Corrected in the Pass 5 rewrite + R12.

### Rot

17. Phase 2 dead weight — resolved (it's the design now).
18. Reviews **A2** asserted the wrong conclusion unmarked. Marked **⚠️ SUPERSEDED**.
19. **T5.11 / D-7** stale. Marked waived.

### Also: R12 corrected
`authentik-server` mounts **no** blueprint volume → the worker roll pauses **background tasks, not login**.
The whole "cluster-wide SSO blip" premise was wrong; R12 downgraded.

---

## Pass 9 — priority re-rank (owner input) ✅

Owner stated the actual priority: **short service disruption is ACCEPTABLE; data loss is NOT.** That is a
constraint, not a pass, but it re-ranks everything and is recorded as **D8**:

- The plan now optimises for **one thing**: zero data loss. Availability is free.
- **R3 / R7 / R9 / R12 downgraded to footnotes** — they cost a brief service gap, which is accepted.
- This **confirms D7's retirement**: its only benefit was dodging an SSO blip we don't care about.
- The gates **sharpen to two objects**. Data-loss vectors are only:
  - `kubernetes_namespace_v1.namespace` — destroy cascades to the PVC → git + DB gone. **Never.**
  - `module.bucket.*` — drops the SeaweedFS bucket → LFS/attachments/artifacts. **Never.**
  - (`helm_release.forgejo` destroy is *survivable* — the chart's PVC is `keep` — so it's a disruption.)
- T5.8, T6.1 and §8's rollback gate were rewritten around **those two objects**, not "any destroy".
- Recovery may freely take a service gap (no quiet-window gymnastics).


