# Forgejo core/mantle split — REVIEW LOG

One section per review pass. Findings get **folded into the core docs**
(`FORGEJO-SPLIT.md`, `-CHECKLIST.md`, `-VALIDATION.md`, `-DEFERRED.md`); this log records the *process*
and the reasoning, including things we deliberately rejected.

**Pass index:** 1 correctness · 2 completeness & risk · 3 executability · 4 adversarial premise-check ·
5 failure simulation · 6 unknowns resolved · 8 hostile findings · 9 priority re-rank (owner) ·
10 backup strategy (owner) · 11 second hostile run · 12 third hostile run · 13 cold read · 14 second cold
read · 15 directed subagents · 16 directed subagents (round 2) · 17 directed subagents (round 3). *(6 ran
before 5; sections are labelled, order on disk is as-completed.)* **Pass 7 (minimality) was dropped** — Q10
settled it: Option A, the only "smaller" option, is off the table.

**Naming, so the letters don't confuse you:** plan decisions are **`D1`–`D9`**; deferred items are
**`DEF-1`–`DEF-13`** (renamed in Pass 14 — they used to be `D-1…`, which collided). The **"D7"** in the
Pass 5/8 text is the *retired* "blueprint as a Secret key" idea; the surviving delivery decision is **D2**.

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

Purpose: stop optimising *how*, and re-test *whether*.

**What it actually fixes:** `mantle` is **greenfield-broken** — `data.external.forgejo_runner_token` reads
the `forgejo-admin` Secret that `module.forgejo` creates **in the same stack** (`set -eu`, no fallback), so
a from-scratch `mantle plan` **fails today**. Moving the instance to `core` puts the Secret before its
reader. (An earlier draft called this "tidiness, not a bug fix" — **wrong**, and the correction is below.)

### Options weighed

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

**Verdict (final, after Q10):** the premise held up **inverted**. The draft's "Option A is defensible"
rested on greenfield not mattering — but greenfield rebuilds are a **DR tenet** (Q10-answered YES), and
`mantle` is already broken for them. Option A is off the table; the split is **necessary** and **fixes a
live DR-blocking bug**. (The "cluster-wide SSO blip" that also propped up Option A was likewise wrong —
R12 is worker-only, login unaffected.)

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
unavailable, DEF-1). This is the one place where "stop and restore" is **mandatory, not optional**.

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

6. **DEF-4 cited the wrong version** ("serves on 15.0.9"; deployed image is **16.0.5**). Fixed.
7. **§1/§3 described a state that isn't on disk** (provider/robot/repos are parked; module still flat).
   Added an explicit **"on disk vs planned"** note to §3.
8. **§1's "no outage beyond a re-login"** understated the **Forgejo pod restart**. Fixed.
9. **V-A3/V-A4 grepped `^module.forgejo`** — matches `module.forgejo_runner` (the exact prefix trap the
   script guards). Fixed → escaped dot + "must return nothing".
10. **"four core docs"; "DEF-1…DEF-9"** — now five, and DEF-1…DEF-11. Fixed.

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
19. **T5.11 / DEF-7** stale. Marked waived.

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

---

## Pass 10 — backup strategy (owner input) ✅

Owner asked two things: **how to back up the LFS**, and **name one place for non-Velero backups**.

### LFS / blob store
The `[storage]` blobs (LFS, attachments, avatars, repo-avatars, artifacts) live in the SeaweedFS bucket
**`forgejo`**, not in `/data` — so `forgejo dump` alone is **incomplete**. Verified the bucket is
S3-compatible and reachable: `aws --endpoint-url https://s3.vn.linuxguru.net s3 ls s3://forgejo/` lists
`lfs/  avatars/  repo-avatars/`. `aws`, `rclone` and `restic` are all installed locally.

**Answer: `aws s3 sync s3://forgejo/ <dest>`**, creds from the `forgejo-s3` Secret, path-style endpoint.

### Landing zone — **D9**
**`/Users/jblack/backups/forgejo/`** with `dump/`, `s3/`, `tfstate/` (+ its own `README.md`). Three pieces,
because no single tool covers the data. Velero keeps its in-cluster BSL; `.tmp/backups/` stays transient.

**This closes the Tier-1 hole.** Before: the entire recovery story was one Velero copy with a 168h TTL and
a dead Longhorn target. Now the critical data (git + DB + config) has an **app-native** copy that restores
without Kubernetes at all, and the blobs have a second copy too.

New deferred: **DEF-12** (nightly `forgejo dump` + S3 sync CronJob), **DEF-13** (a second, off-site Velero BSL —
only one exists today, so even Velero shares a failure domain).

---

## Pass 11 — second hostile run, end to end ✅ (all folded)

Second adversarial read. **15 defects**, all fixed. Nothing changed the *design* — this was drift plus three
real gaps.

### Broken (reading order / load-bearing names)
1. **§5's decision list was scrambled.** `grep` proved `D7` sat at **line 125, *after* the `Rejected:` line**
   at 122 — so §5 read D1–D6, D8, D9, Rejected, D7, with a stray blank slot. Two of my own edits had
   inserted D8/D9 *before* `Rejected:`. **Reordered** to D1–D9 → Rejected.
2. **§4 contradicted the checklist on a load-bearing name**: §4 said mantle's CI module is `module "forgejo"`,
   while T4.4/V-A4 rename it **`forgejo_setup`** precisely to avoid two `forgejo` modules. §4 fixed.

### Stale counters
3. Header said `passes 1–6` → **1–10** (+ D1–D9).
4. §11 said "decisions D1–D7" → **D1–D9**.
5. §11 said "passes 1–6 plus Pass 8" → **1–10**.
6. REVIEWS **pass index** stopped at 6 → now lists **8, 9, 10**.
7. V-G1 pointed at the transient `.tmp/backups/*` → now the **D9** home.
8. Gates summary item 7 said "fresh Velero backup" → now the **4-part DR set**.

### Contradiction / dead weight
9. **T4.11 (serialize the helm behind authentik) was guarding a race D8 declared irrelevant** — dropped, with
   the reasoning recorded in D8 and §11.
10. **D6 vs Q2**: D6 asserted `client_secret` "may rotate"; Q2 says it's **preservable**. D6 now states the
    *choice*.

### Real gaps
11. **No `depends_on` for the robot's project.** `harbor_robot_account` targets project `library`, created by
    `module.harbor_setup` in the **same stack** — the exact same-stack ordering bug this project exists to
    fix. Added to §4 and **T3.3**.
12. **The workflow secret names were nowhere** in the target state (`HARBOR_USER`/`HARBOR_TOKEN` only existed
    in V-E4). Added to §4 and T3.3.
13. **No task declared `forgejo_registry_repos`** (only "decide the list"). Added **T3.7**.
14. **§4 never mentioned the `tls` provider** — a required core addition, previously only in T4.9. Added.
15. **V-C4 was circular** (it leaned on V-A2's "no changes"). Rewritten to check **authentik directly** —
    a changed group UUID would re-read silently and still plan clean.

---

## Pass 12 — third hostile run ✅ (all folded)

Third adversarial read. **9 defects**, all fixed. Two were *self-inflicted by Pass 11's own fixes*.

### Contradiction (the one that mattered)
1. **§7 R5 outright contradicted T5.7.** R5's mitigation read *"Plan must show **no change** to
   `helm_release.forgejo`"*, while T5.7 explicitly expects **exactly one update** to it (the new
   `client_secret`). Two gates, opposite instructions. R5 rewritten: expect exactly one `update`; a
   **`destroy`** must not appear. (R5 also re-labelled: a helm recreate is *survivable*, D8.)

### Stale (two of them self-inflicted)
2. **Header + §11 said "passes 1–10"** — because Pass 11's fix set them to 1–10, and then Pass 11 existed.
   Now **1–11**.
3. **REVIEWS pass index omitted Pass 11** — it listed 8/9/10 but not the pass that had just happened.
4. **§7 R3's mitigation still said "do it in a quiet window"** — stale under D8/T6.6 (availability is
   free). Reworded to "Accepted (D8)".
5. **§6 S0 called the Velero backup "off-box"** — its BSL is **in-cluster** (DEF-13), so it shares the
   failure domain. Corrected.
6. **§6 S6 said "zero destroys"** — the pre-D8 gate; now "zero destroys on the namespace or the bucket".

### Muddle / small gaps
7. **§7's closing note mis-grouped the risks** ("R1, and R2/R5 insofar as they could cascade"). R2 is
   *config*, R5 is *survivable*. Rewritten: **R1 is the only data-loss row**; R2/R6/R8 are config;
   R3/R5/R7/R9/R11/R12 are availability.
8. **§6 S4 didn't name the mantle module** `forgejo_setup`. Fixed.
9. **`discovery_url` had no producer.** T3.2 requires it in the `oidc` input, but nothing emitted it —
   now `oidc_blueprint` outputs it (§4).

---

## Pass 13 — cold read (a no-context reviewer) ✅ (all folded)

An independent agent with **zero prior context** read all five docs plus the move script, the live module
code, and the provider cache. It was positive on the mechanics (DAG acyclic, greenfield bug real, `tls`
missing, `forgejo_repository_action_secret` exists) and found **14 things**. Every one was valid — the
best external pass so far.

### Missing (the plan had holes)
- **M1/D-β — nobody said how `provider "forgejo"` authenticates.** A whole build step with no design.
  → T4.7 now specifies the house pattern: a `data.kubernetes_secret_v1` on the chart-minted
  `forgejo-admin` Secret (`host` + `username`/`password`); no new credential.
- **M2 — provider version unpinned** (every neighbour is pin-exact) → **`svalabs/forgejo` 1.6.1**.
- **M3 — no rendered-helm-values diff.** T5.7 assumed "exactly one update", i.e. that the re-plumbed OIDC
  block renders byte-identically. Unproven. → new **T5.0** pre-gate: capture `helm get values` before, and
  confirm after that only the OAuth `client_secret` moves.
- **M4 — the exact `discovery_url` string was never stated** (trailing slash included) → spelled out in §4.
- **M5 — TWO redirect URIs, not one.** `auth.tf` sets the callback **and** `extra_redirect_uris = [site
  root]`. §9/§10/T1.7 spoke generically; V-C8 named only the callback. → T1.4 + V-C8 now require both.
- **M6 — no restore drill.** "Data is sacred" (D8) with an untested backup is a wish. → **V-B10**.
- **M7 — `forgejo_registry_repos` still undecided** → already T3.6/T3.7; confirmed open (it's an owner call).

### Confusing
- **C1 — pass counter stale by one** (1–11 while Pass 12 existed). Ironic: Pass 12's own fix #2 was the
   same off-by-one. → **1–12**, index updated.
- **C2 — D2 and D7 were the same decision**, and "D7" had meant two different things across the log.
  → merged into **D2**; the log carries a naming note.
- **C3 — T1.7 said "copy every field verbatim from `auth.tf`"**, but ~6 fields are provider *defaults*
  absent from that file. → T1.7 now points at `.tmp/authentik-export.yaml` for them.
- **C4 — the move script's dependency audit was opaque** (and its `".oidc" == d[-5:]` clause was dead
  code). Reviewer was *half* right: the "outside `module.forgejo`" test already caught the real case, but
  the message didn't say so. → rewritten: flag only deps that **stay behind**, with the sibling-module
  reasoning in a comment.
- **C5 — two backup homes, no statement of precedence** → checklist now says which is authoritative for
  the surgery vs retention.
- **C6 — the `oidc` input's values were unstated** (a wrong `scopes`/`group_claim` is a silent R8 break)
  → §4 gives the exact values.

### Decisions
- **D-α — preserve vs rotate `client_secret`.** T5.7/R5 hard-assumed rotation while D6 hedged. → **D6 now
  commits to ROTATE** (a brief mismatch window is accepted under D8).
- **D-δ — don't carry `email_verified`** into the blueprint (Forgejo uses the built-in `email` mapping)
  → stated in T1.4.

**Verdict from the cold reader:** *"unusually rigorous… the mechanics, DAG and state-move are sound"*; the
soft spots were provider auth/version, the unproven byte-identical assumption behind T5.7, the missing
restore drill, and doc hygiene. All now closed.

---

## Pass 14 — second cold read ✅ (all folded)

A second no-context reader, told there had been 12 passes, "went looking for what those passes missed".
It found **8 more**, and the important ones were real **Phase-3 traps**:

### Phase-3 traps (the meat)
- **N1 — `helm.tf` has a SECOND `module.oidc` reference.** `depends_on = [module.bucket, module.s3_user,
  module.oidc]`. T3.1/T3.2 only mentioned the *values* reference (`locals.tf:86`). Copy `helm.tf` verbatim
  and `tofu validate` dies with *reference to undeclared module*. Now named explicitly.
- **N2 — "locals (minus `oidc_*`)" is a trap.** A literal reading deletes
  `local.oidc_source_name = "authentik"`, which names the OAuth **source** at `locals.tf:84` — silently
  renaming it changes `app.ini`: the R8 class. Replaced the hand-wave with an exact **DELETE / KEEP**
  symbol list.
- **N3 — the `oidc` input's wiring was under-specified.** `oidc = module.forgejo_oidc.*` can't satisfy the
  input, because `scopes`/`group_claim`/`admin_group`/`restricted_group` are **stack literals**, not module
  outputs. §4 now pins the module's outputs to exactly `client_id`/`client_secret`/`discovery_url`, and
  T4.1 spells the object out.

### Confusion / hygiene
- **N5 — `tls` unpinned** in core (every neighbour is pin-exact) → **4.4.1**, matching mantle.
- **N6 — three framings of `depends_on = [module.authentik]`** (§4/§11 implied it, D8 called it "optional",
  §11 said it "orders helm updates only"). Now **retired outright** in one place — D8 makes the race
  irrelevant, so don't add it.
- **N7 — two decision namespaces collided**: plan `D1–D9` vs deferred `D-1…D-13` (which had *already* bitten
  us twice). Renamed the deferred family to **`DEF-1…DEF-13`** across all five docs + the todo memory.
- **N8 — mantle's plan is no longer standalone.** `data.external.forgejo_runner_token` now reads a Secret
  **core** owns, so a from-scratch `mantle plan` needs a live core — the corollary of the greenfield tenet
  (DEF-10). Now stated in §4.

**N4** (`forgejo_registry_repos` undecided) was already tracked (T3.6/T3.7) and remains the one genuine
**owner-gated** decision — it hard-blocks V-E4.

**Reader's bottom line:** *"the risks/gates are solid… the soft spots are all in Phase 3's 'trim the oidc
bits' step — it's described by pattern (`minus oidc_*`, `.*`) where it needs an exact symbol list."*
Agreed, and now it has one.

---

## Pass 15 — three directed subagents ✅ (all folded)

Rather than another blind read, three subagents were spawned with **specific hypotheses to falsify**, each
told to be adversarial and cite evidence. They found **more than either cold read**, and one of them
disproved a claim I had asserted for twelve passes.

### A — authentik blueprint feasibility: *verified*, with two hard catches
All eight claimed mechanics **VERIFIED** (against authentik's own source, the live export, and upstream
blueprints): identifier-based adoption, `client_secret` writable, `!Find` on `managed`, custom scope
mappings by `name`, cert PEMs, atomicity, and `redirect_uris` (not `allowed_redirect_uris`).
- **A1 — the two policy bindings are BOTH `order: 0` on the same target.** `identifiers: {target, order}`
  therefore **cannot distinguish them** — `.first()` returns one row for both, leaving an orphan binding or
  spawning a third, thrashing every apply. → **Q4 corrected to identify by `{target, group}`.**
- **A2 — `signing_key` was never in the fidelity list.** Adoption-by-`name` preserves the pk, but it must be
  set explicitly or it could silently resolve to a new cert → invalid tokens. Added.
- **A3 — `client_secret` must be ASCII** (`validate_client_secret`), and it is re-applied every apply.
  Both added to §9.

### B — symbol completeness: 5 real MISSES
- **B1 — `variable "auth_gateway_name"`.** Its comment claims *"Only the OIDC egress peer uses this"*, so a
  literal "delete the OIDC bits" deletes it — but `egress.tf:22` uses it for the gateway peer that also
  carries **S3**. Deleting it → dangling var → validate fails. **KEEP**, and fix the lying comment.
- **B2/B3/B4 — the kept `gitea.oauth` block** (`locals.tf:86-92`): `key`/`secret` still read the dead
  module, `autoDiscoverUrl` eats the **deleted** `local.oidc_issuer`, and `adminGroup`/`restrictedGroup`
  had **no named consumer** for the new input keys.
- **B5 — `authentik` in `providers.tf`** was only implied, not named.
All folded into T3.1's DELETE / REWRITE / KEEP / STRUCTURE triage.

### C — state-move verification: *the audit was worthless, and I was wrong about imports*
- **C3 — `terraform_data` CAN be imported.** I asserted the opposite for twelve passes as D5's whole
  justification. **Verified myself on OpenTofu 1.13.1: `Import successful!`** → D5's rationale corrected
  (JSON surgery is still right, but for identity-preservation, not importability).
- **C4 — the script's dependency audit is vacuous.** It reads a `dependencies` field that is **empty in
  these states**, so `"stale deps: none"` verified nothing. Annotated; the check itself is now advisory.
- **C1 — the count-index trap.** `…expose.module.http_route[0]` exists only because `backend_name != ""`;
  drop it and terraform **destroys the git HTTPRoute**. And declaring `module "forgejo"` with `count`
  (as `harbor`/`argo` do) would shift every address to `[0]` and **destroy the namespace**. Both now
  hard-flagged.
- **C7b — the double push is not transactional.** Two backends, no transaction: pushing core first leaves a
  window where both states own the objects. → **Push mantle first, verify it is clean, then core.**
- **C7c — Phase 3/4 must land before Phase 5**, or core's plan destroys the namespace. Now a Phase-5
  prerequisite gate.

---

## Pass 16 — second directed-agent wave ✅ (all folded)

Three agents, three *different* perspectives, each handed one claim to **falsify** and told that a clean
"VERIFIED" is a good result. Two of them falsified things; the third falsified a claim we had already
quietly accepted. Every headline finding was then **re-verified by me by hand** before folding.

### Agent A — Helm value fidelity (hypothesis: *"same values, different sourcing ⇒ byte-identical render"*)
- **A16-1 — FALSIFIED, by design.** `D6` *rotates* the `client_secret`, so the render is **not** identical:
  the rendered init flags and the `checksum/oauth_0` annotation change ⇒ the pod rolls (accepted, D8/R9).
  The word "byte-identical" was doing dishonest work; only **3** keys ever touched the dead symbols
  (`key`, `secret`, `autoDiscoverUrl`) and the chart emits those flags in **Go-template sorted-key order**,
  a pure function of the value set. So the *real* claim — "nothing else silently moves" — is **VERIFIED**.
- **A16-4 — THE SILENT BOMB.** Group names derive as `"${var.name}-admin"`/`"-user"`
  (`oidc_provider/auth.tf:157-163`). The plan pinned the **consumer** (`forgejo-admin`) but never the
  **producer**. If the new module's `name != "forgejo"`, authentik creates `forgejo-oidc-admin` while
  Forgejo is told to read `forgejo-admin` — **login works, nobody is admin, zero errors.** Exactly the
  silent class R8 exists to catch. → pinned in T1.3 + D3.
- **A16-6 — doc drift with teeth.** The plan says the OAuth config is "baked into `app.ini`". **It isn't** —
  it's a DB `login_source` row re-synced by the init container every pod start. Nobody was guarding the
  wrong thing, but R8's *framing* was. Corrected in T1.7.
- A16-3: `discovery_url` value verified; construction now pinned (no trailing slash).

### Agent B — rollback realism (hypothesis: *"the documented rollback restores service and loses no data"*)
- **R16-1 — the rollback command DOESN'T RUN.** §8 said `state push <backup>` with **no `-force`**; after
  surgery the remote serials are *ahead* (mantle 1170 vs 1169, core 784 vs 783), and terraform **refuses**
  to write an older serial. The rollback would fail at 3am, mid-incident. → `-force` added.
- **R16-2 — the rollback could CAUSE the data loss it exists to prevent.** "Restore state, then `apply` to
  converge back" is a trap: state-without-code renders `destroy namespace` + `destroy bucket` plans, and one
  careless apply **creates a fresh empty PVC.** → §8 replaced with a **state-only, never-apply drill**.
- **R16-3 — the D9 vault is EMPTY.** Only `README.md`; `dump/`, `s3/`, `tfstate/` all **0 bytes** (verified
  myself). The checklist claimed backups "now live" there — a **false** claim of DR cover. The only real
  copy is an in-cluster Velero backup. → Phase 0 corrected; T6.0 is now load-bearing.
- **R16-8 — the rollback push order was undocumented**, and it is the **reverse** of the forward order
  (core first, then mantle); then never apply between pushes.
- VERIFIED (good news): the Velero backup is real (54/54), the forget-list cannot touch a PVC, the script
  preserves pre-move bytes, and the **forward** order is destroy-free.

### Agent C — cross-stack coupling (hypothesis: *"nothing silently depends on the other stack being applied first"*)
- **C16-9 — the big one, and it contradicts a Pass-15 conclusion.** Moving the instance into `core`
  converts four orderings that were **satisfied for free by cross-stack sequencing** into **unguarded
  same-stack** ones, because the module reaches its producers through *defaulted string literals*, not
  module refs: `bucket`/`s3_user` `kubectl exec` into SeaweedFS; `module.backup` needs core's Velero CRDs
  (core's own analogue has an explicit `depends_on = [module.backup]` — `modules/storage/backup.tf:31`);
  `expose`/`egress` default to the `private` gateway. **No edge, so a from-scratch `core` apply races.**
  Invisible during the migration only because the state surgery preserves the live objects — it goes red on
  rebuild (DEF-11). → T4.1 now demands explicit `depends_on`.
- **C16-6 — D3's `data.authentik_group` reads an ASYNC producer.** The groups appear when the authentik
  **worker** ingests the blueprint (start-up or the 60-min scan), not at apply time — so a `mantle plan`
  that beats the worker fails. → T6.3c gate.
- **C16-7 — the DAG is a FORK, not a chain.** `forgejo_oidc → {authentik, forgejo}`; D8 retired the only
  `authentik→forgejo` edge. Still acyclic, but the drawing lied.
- **C16-8 — T5.7's "exactly one update" was wrong**: `extra_blueprints` mutates the `blueprints.secrets`
  helm value, so `module.authentik.helm_release.helm` updates **too**. The gate would have STOPPED the
  operator on an expected change. → corrected to two.
- Also falsified again: `mantle` was **never** standalone — it already plan-time-reads core's authentik/
  harbor/argocd Secrets (the acknowledged N8). The split re-labels that dependency; it does not remove it.

**A16-2/A16-5/C16-1..C16-5 all VERIFIED** (three keys touch OIDC; `depends_on` removal harmless; the
same-stack bug is real; no TF cycle; blueprint-without-provider mechanism sound; `svalabs/forgejo` 1.6.1
exists). **Net: 11 findings folded, 3 of them capable of causing silent data loss or silent zero-admin.**

---

## Pass 17 — third directed-agent wave ✅ (all folded)

Fresh angles: the **adoption prover**, the **greenfield-rebuild prover**, the **interface attacker**. All
three falsified something again — and one caught a bug **I introduced in Pass 16**.

### D — adopt-don't-duplicate (hypothesis: *"the blueprint adopts existing objects; it cannot match the wrong one or duplicate"*)
The strongest evidence of any review so far: the agent rebuilt the plan's blueprint entries and ran
`Importer._apply_models()` inside a `transaction_rollback()` **on the live worker**. All 8 entries
**ADOPTED their exact baseline pk** (provider→57, app→`03666c87`, both policy bindings). Every identifier
was genuinely unique cluster-wide (43/43 group names, 19/19 app slugs, 16/16 providers, 11/11 certs,
24/24 scope-mapping names; each `managed` filter hit exactly one row). **The claim holds today.**
- **D17-1 — BUT the mechanism FAILS OPEN.** `!Find` with **no** match returns **`None`, not an error**, and
  `.first()` has **no multi-match guard**. Tested: `signing_key: !Find [cert,[name,DOES-NOT-EXIST]]` →
  `apply_ok=True`, provider adopted **with `signing_key=None`**, zero errors. So Pass 15's mitigation
  ("set it explicitly so it can never silently resolve to a *wrong* cert") does **not** protect against a
  *missing* one — and a signing-key-less provider invalidates every issued token. → T1.2 now mandates
  **`!KeyOf` to same-blueprint entries** and strict entry ordering.
- **D17-2** — a miss normally creates a **duplicate**, loud only where `name` is unique; **`policybinding` is
  the one model that can duplicate silently** (its `unique_together` defeated by a NULL `policy`). The A16-4
  trap is therefore a *silent wrong-named create*.

### E — greenfield rebuild (hypothesis: *"after the split, a from-scratch rebuild of core then mantle succeeds"*)
- **E17-1 — I BROKE IT IN PASS 16.** C16-9 made T4.1 add `depends_on = [module.seaweedfs, module.backup,
  module.network]`. But `stacks/core` declares **no `module "backup"`** (verified: core declares only
  network/storage/cert_man/authentik/harbor/argo/seaweedfs/…). I copied a line from a *module-internal*
  file (`modules/storage/backup.tf:31` — correct there) into *stack* scope, where it is a hard
  `tofu validate` failure: *"reference to undeclared module"*. → corrected to **`module.storage`**.
- **E17-3 — the plan optimises the PLAN and hand-waves the DATA.** A rebuild has an empty PVC and an empty
  DB; nothing in the checklist restores either, and DEF-1/12/13 turn out to be **load-bearing
  prerequisites, not follow-ups**. → new **DEF-14**; DEF-1/12/13 marked load-bearing.
- **E17-4 — D6 rotation + any DB restore = silent SSO failure.** The source is a DB `login_source` row;
  restoring an *old* DB while carrying the *new* secret makes the token endpoint reject while the login page
  still renders. → folded into D6 with a restore-ordering rule.
- **E17-2** — the async-group gate (T6.3c) is a *human* check, so an unattended rebuild still fails. Noted.

### F — interface contract (hypothesis: *"the `oidc` input cannot be populated with a value that type-checks but silently breaks OIDC"*)
- **F17-1 — `scopes` is a comma-split flag living in a free-form string.** Forgejo reads `--scopes` via
  `StringSlice`; `"openid email profile groups"` (spaces), `""`, or any list missing `groups` **validates and
  silently drops the groups scope → nobody is admin, no error.** → validation added (T3.2).
- **F17-4 — the blueprint Secret's key must end in `.yaml`, and `list(string)` cannot express that.** Proof
  in-repo: `modules/auth/authentik/core/scopes.tf` writes **`terraform.yaml`** (applied) *and* **`api_key`**
  (silently ignored) into one Secret. A correctly-named Secret keyed `blueprint` **mounts and is never
  applied** — the provider is simply never created. → pinned in T1.3.
- **F17-2/F17-3/F17-5** — `admin_group`/`restricted_group` and `group_claim` are hand-written stack literals
  opposed to producer-derived values, with **no `validation` anywhere** on the input. The A16-4 link was
  pinned only by *prose*; now it is validated.

**Net: 9 findings folded, 3 severe — E17-1 (a self-inflicted validate break), D17-1 (a fail-open path to a
signing-key-less provider), F17-4 (a blueprint that mounts and is silently never applied).** The yield is
**not** decaying.


