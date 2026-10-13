# Forgejo core/mantle split — REVIEW LOG

One section per review pass. Findings get **folded into the core docs**
(`FORGEJO-SPLIT.md`, `-CHECKLIST.md`, `-VALIDATION.md`, `-DEFERRED.md`); this log records the *process*
and the reasoning, including things we deliberately rejected.

**Pass index:** 1 correctness · 2 completeness & risk · 3 executability · 4 adversarial premise-check ·
5 failure simulation · 6 unknowns resolved · 8 hostile findings · 9 priority re-rank (owner) ·
10 backup strategy (owner) · 11 second hostile run · 12 third hostile run · 13 cold read (no-context
reviewer). *(6 ran before 5; sections are labelled, order on disk is as-completed.)* **Pass 7 (minimality)
was dropped** — Q10 (greenfield is a DR tenet) settled it: Option A, the only "smaller" option, is off the
table. *(Naming note: the "D7" in the Pass 5/8 text is the **retired** "blueprint as a Secret key" idea;
the surviving delivery decision is **D2**.)*

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

New deferred: **D-12** (nightly `forgejo dump` + S3 sync CronJob), **D-13** (a second, off-site Velero BSL —
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
5. **§6 S0 called the Velero backup "off-box"** — its BSL is **in-cluster** (D-13), so it shares the
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


