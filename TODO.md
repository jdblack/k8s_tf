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

Guest lists above come from real flow data (Goldmane/Whisker), not guesses.

Why the node CIDR: a pod always accepts traffic from its **own** node, but the
apiserver may call a webhook / aggregation endpoint from a **remote** node —
which is policy-gated. That is also why media's `etp=Cluster` LBs failed under
the firewall while `etp=Local` worked.

### Method (validated 2026-09-12)
Add a `staged` flag to `firewalls/policy` (+ pass-through on `limited_ingress`)
that renders a `StagedKubernetesNetworkPolicy` (`crd.projectcalico.org/v1`)
instead of the typed `kubernetes_network_policy_v1` — same rules, NOT enforced.
Calico then records would-be DENIES in the flow logs (`pendingPolicies`), so each
namespace is: stage → watch a few days (trigger the real paths: a login, an argo
sync, a fresh image pull) → flip `staged = false`.

Caveat: it only previews where the staged policy would be the *deciding* one.
A namespace that already has a permissive netpol just unions and previews nothing.
Verified working: staged an allow-list on `argo` and saw `pendingPolicies: Deny`
for a probe from `default`, while the traffic still flowed.

## Follow-ups

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

## Owed notes

- `modules/network/wireguard/main.tf` points here for "the systemic unpinned-helm
  note" — that note isn't written yet (workload modules pin chart+image versions
  ad hoc; the wireguard one is explicit about it).
