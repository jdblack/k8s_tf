# TODO

## Namespace ingress rollout — the "media treatment", part 2

`media` is locked down (netpols from 2026-09-12). These are NOT — any pod in the
cluster can still reach them:

| namespace | intended guest list | notes |
|---|---|---|
| `kube-auth` | self, kube-network, **media** | the outpost calls authentik by ClusterIP directly |
| `devops-harbor` | self, kube-network | chart-rendered route on the private gateway |
| `argo` | self, kube-network | (argo has NO egress fence either — `enable_egress_firewall=false`) |
| `ai` | self, kube-network | |
| `monitoring` | self, kube-network + **node CIDR** | metrics-server aggregation + operator webhook are node-sourced |
| `kube-certificates` | self + **node CIDR** | cert-manager webhook |
| `blender` | self + **node CIDR** | samba LoadBalancer |

Guest lists above come from real flow data (Goldmane/Whisker), not guesses. The
node-CIDR rule and the staged-policy preview caveat are in
`.clinedocs/calico-netpols.md` — don't re-derive them.

### Method (validated 2026-09-12)
Add a `staged` flag to `firewalls/policy` (+ pass-through on `limited_ingress`)
that renders a `StagedKubernetesNetworkPolicy` (`crd.projectcalico.org/v1`)
instead of the typed `kubernetes_network_policy_v1` — same rules, NOT enforced.
Calico then records would-be DENIES in the flow logs (`pendingPolicies`), so each
namespace is: stage → watch a few days (trigger the real paths: a login, an argo
sync, a fresh image pull) → flip `staged = false`.

Verified working: staged an allow-list on `argo` and saw `pendingPolicies: Deny`
for a probe from `default`, while the traffic still flowed.

## Follow-ups

- **vaultwarden backups are cluster-local.** Snapshots live with the volume, and
  the `longhorn` StorageClass is `reclaimPolicy: Delete`, so losing the cluster
  (or destroying the module) loses them. Next step: point Longhorn's
  `backupTarget` at the SeaweedFS S3 endpoint and flip the RecurringJob in
  `modules/vaultwarden/backup.tf` to `task = "backup"`. Until then: export from a
  client before any destroy.
- **vaultwarden has no metrics to scrape.** 1.37.3 dropped the metrics build
  feature — no `/metrics` route, no `PROMETHEUS_ENABLED` (only `GET /alive`), so
  the module ships no ServiceMonitor. Re-check upstream in a later release; if it
  returns, add `monitoring.tf` and put `monitoring` in the ingress guest list in
  `modules/vaultwarden/security.tf`.
- **Whisker UI**: confirm the flow list populates *through the authentik proxy*
  (the UI pulls flows over gRPC-web; a proxy may buffer it). Fallback:
  `kubectl -n calico-system port-forward svc/whisker 8081:8081`.
- **`goldmane:7443` stays readable by any pod**: the tigera-operator's own
  `goldmane` netpol allows every source on 7443, and k8s policies only UNION, so
  it can't be tightened from Terraform. Override the operator object, or accept.
- **media NodePort soft spot**: a pod can still reach the LB-exposed services via
  `nodeIP:nodePort` (masqueraded to the node IP). Accepted; an internal-only
  `loadBalancerClass` would close it.
- **authentik group membership is hand-managed** (`jblack` in `platform`, and the
  `media` group): a from-scratch rebuild needs it re-added by hand. Either keep the
  convention ("TF owns structure, UI owns people") or move members into TF.
- **Optional**: a `posture` wrapper so a namespace states egress+ingress in one
  call instead of 2-4 module calls (deferred until after the rollout).
- **Longhorn has no Grafana dashboard.** Longhorn manager metrics are already
  scraped, but the upstream dashboard
  (https://grafana.com/grafana/dashboards/22705-longhorn-dashboard/) was never
  imported. Do it the SeaweedFS way: a `grafana_dashboard: "1"` ConfigMap
  shipped next to `modules/storage/longhorn.tf`. (This was the stray
  `modules/storage/TODO` note; that file is gone.)
- **`ollama.vn.linuxguru.net` has no auth in front of it.** It is on the
  *private* gateway, so LAN/VPN only — but anything on the LAN can drive the
  model server. It is created by the external app-of-apps repo, so gating it
  means an authentik proxy app either there or here.
- **Leftovers to delete**: the `kube-security` namespace
  (`stacks/mantle/security.tf`, kept only because it is in state) and the
  orphaned `tfstate-default-fuckbatz` Secret in `kube-system` (see
  `stacks/apps/README.md`).

## Follow-ups out of the vaultwarden build (shipped + verified 2026-09-14)

The 33 KB handoff doc that used to live here is gone — its durable content is in
`modules/vaultwarden/README.md` (design, env, backups, offline behaviour, drift
test) and `modules/network/dns/route53_record/README.md` (the `GetHostedZone`
trap). What it left behind:

- **`modules/cert_manager/external_cert.tf` writes an invalid route53 solver
  field.** `zoneid = var.data["R53_ZONEID"]` — cert-manager logs `unknown field
  "spec.acme.solvers[0].dns01.route53.zoneid"` and prunes it, so the zone was
  never pinned. The real field is `hostedZoneID`. (The `http01: {}` block in the
  same file is also a non-field: harmless, but misleading.) See the module
  README's Traps.
- **external-dns never published `certtest.vn.linuxguru.net`** from its HTTPRoute
  annotation (7+ minutes, nothing in bind9). Understand why before relying on
  automatic `.vn` DNS for a new app.
- **Idea: retire `linuxguru-ca`** by issuing letsencrypt certs for `.vn` names
  too. Needs the `hostedZoneID` fix above plus `--dns01-recursive-nameservers`
  on the solver (the propagation self-check resolves through bind9 for the `vn`
  subtree). Partially proven: with `hostedZoneID` set, the TXT did reach Route53.
- **Dead config**: `deployment.dyndns_host` in `k8s.tfenv` (same `lg-route53`
  key, `FQDN = home.linuxguru.net`) is a defunct dynamic-DNS setup — no `.tf`
  references it. Safe to delete.
