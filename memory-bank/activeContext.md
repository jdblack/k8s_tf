# Active Context

## Current state (as of memory-bank init, 2026-09-14)

- Branch `main`, working tree clean except two untracked doc paths: the
  `.clinerules/memory bank.md` rule file and this `memory-bank/` directory.
- HEAD `9cc2a0b docs: clarify stack layout, apply order, and state handling`.
- The vaultwarden build shipped and was verified live on 2026-09-14. The big
  33 KB handoff doc was retired into `modules/vaultwarden/README.md` and
  `modules/network/dns/route53_record/README.md`.
- Media namespace is the only namespace with real (enforced) NetworkPolicies
  (locked down 2026-09-12). Everything else is still open to any cluster pod.
- The `staged` (preview-only) NetPolicy *mechanism* is proven — an allow-list
  staged on `argo` logged `pendingPolicies: Deny` while traffic kept flowing.
  But **the `staged` flag does not exist in the code yet** (grep verified
  2026-09-14): no `staged` var in `modules/network/firewalls/policy` or
  `limited_ingress`. The proof was a hand-run object. Implementing that flag is
  the first concrete task of the rollout.

## In-flight work

**Namespace ingress rollout, part 2** — the "media treatment" for the remaining
namespaces. Method (validated by hand, not yet in code): render staged policies
via a `staged` flag on `firewalls/policy` (+ pass-through on `limited_ingress`),
stage → watch a few days with real traffic (a login, an Argo sync, a fresh image
pull) → flip `staged = false`. Intended guest lists per namespace are in
`TODO.md`; they come from Goldmane/Whisker flow data, not guesses. Highest-value
first candidates: `kube-auth`, `devops-harbor`, `argo`, `ai`, `monitoring`,
`kube-certificates`, `blender`.

Note `argo` also has **no egress fence** (`enable_egress_firewall=false`).

## Immediate follow-ups owed (from `TODO.md`)

- **vaultwarden backups are cluster-local** → point Longhorn `backupTarget` at
  the SeaweedFS S3 endpoint + flip the RecurringJob to `task = "backup"`. Until
  then: export from a client before any destroy.
- **`modules/cert_manager/external_cert.tf` writes `route53.zoneid`**, which is
  not a real cert-manager field (prunes, logs a warning). Real field:
  `hostedZoneID`. Same file's `http01: {}` is a non-field (misleading, harmless).
- **external-dns never published `certtest.vn.linuxguru.net`** from its HTTPRoute
  annotation — understand why before relying on automatic `.vn` DNS.
- **Longhorn has no Grafana dashboard** — ship it the SeaweedFS way next to
  `modules/storage/longhorn.tf`.
- **Whisker UI**: confirm the flow list populates *through the authentik proxy*.
- Leftovers to delete: the `kube-security` namespace (kept only because it's in
  state) and the orphaned `tfstate-default-fuckbatz` Secret.

## Decisions that are settled — don't relitigate

- Three stacks, in order; state in k8s Secrets.
- Typed `kubernetes_*` over `kubectl_manifest`, so `plan` sees drift.
- TF owns groups/apps/bindings; the authentik UI owns membership.
- No `-target`/`-exclude`.
- `parse the narrowest doc first` — root README → module README → `.clinedocs/`.

## Reading order for a fresh session

1. Root `README.md` (map, hostnames, conventions).
2. `TODO.md` (what's actually open).
3. The `README.md` of the one module you're touching.
4. `.clinedocs/calico-netpols.md` or `.clinedocs/flow-logs.md` only if the task
   is a NetworkPolicy / flow-query task.
