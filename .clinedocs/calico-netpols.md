# Calico NetworkPolicy invariants — and the operator's own policy tier

Conserved 2026-09-16 when the first firewall layer was deleted, and now the reference for the
rebuilt one. Read this before adding or debugging a policy; the module's own docs
(`network/firewalls/egress/README.md`, `network/firewalls/README.md`) cover what a call renders,
this covers the dataplane and the operator underneath it. Flow-query recipes:
`.clinedocs/flow-logs.md`.

## Tier ordering — the operator's deny outranks every k8s NetworkPolicy here

- A `NetworkPolicy` compiles into Calico tier `default`. tigera-operator `v3.32.2` moved its own
  rules into tier `calico-system` (`order: 100`, `defaultAction: Deny`), which is evaluated
  **first**, so its end-of-tier DROP pre-empts anything in `default`. Nothing the operator denies
  can be re-opened from a k8s netpol — only from a CR *in that tier*.
- A CR in that tier needs an **explicit `spec.order`** to beat the operator's unset-order
  deny-alls (`order: 10` for ours). That is the whole trick behind `network/whisker/tier.tf`.
- The operator's canonical namespace selector is
  `namespaceSelector: projectcalico.org/name == '<ns>'`.
- Reading a flow record: `policies.enforced[].trigger.name` is the **deciding** policy;
  `policies.enforced` reading empty means *default* deny, not "no policy"; `EndOfTier` with
  `name: ""` is the tail deny of the tier that decided (in `calico-system` that is the operator's
  `default-deny`).

## Egress is evaluated POST-DNAT

- A dial to a Service ClusterIP is DNAT'd to an endpoint before the policy chain runs, so allow
  rules match the **endpoint** IP. Measured on this cluster (iptables dataplane, one scratch
  policy per port): `10.96.0.1:443` alone permits nothing; the node address on `6443` alone
  permits the ClusterIP dial. `allow_k8s_api` renders **both** rules for exactly this reason.
- Consequences: Whisker's `dest_port` is the target *pod's* port, and a ClusterIP handed to
  `to_cidrs` is dead by construction.
- **A LoadBalancer VIP is dead the same way** (measured 2026-09-17, harbor). A pod dialling a
  published hostname sends to the gateway VIP, and the policy sees the DNAT target: `harbor-core`
  → `192.168.0.100:443` read as `kube-network/private-private-6f99f96d5f-*:443`, and a
  `to_cidrs = ["192.168.0.100/32"]` rule permitted nothing. The working peer is a namespace + pod
  selector + port (`network/firewalls/egress_peer`, 443 on
  `gateway.networking.k8s.io/gateway-name=<gw>`). Reading the deny is how this was established:
  `policies.enforced[].trigger.name` named `harbor-egress`, `kind: EndOfTier`.
- Related: the apiserver calls webhooks/aggregation from a **remote node**, so those paths need
  the **node CIDR**. Same root cause makes `externalTrafficPolicy=Cluster` LoadBalancers
  (blender samba, WireGuard) break under a firewall while `etp=Local` (media, both gateways) pass.

## netpols only UNION

- Every policy selecting a pod adds allows; nothing subtracts. An operator- or chart-shipped
  netpol therefore **cannot be tightened** from here: tigera's `goldmane` allows any source on
  7443 (accepted, unfixable from TF), and argo-cd's six chart netpols are switched off with
  `global.networkPolicy.create = false` rather than narrowed.
- **`global.` in a chart value is Helm's shared-values map, not cluster scope.** argo-cd's
  `global.networkPolicy.create` gates six `networking.k8s.io/v1 NetworkPolicy` objects that all
  carry `namespace: <release namespace>` and one component `podSelector` each — verified by
  rendering 10.9.1 both ways: 59 objects vs 53, delta exactly those six, none cluster-scoped.
  The prefix exists because the chart has a `redis-ha` subchart, which inherits `global` values.
  What *is* cluster-scoped in that chart is RBAC and CRDs (`createClusterRoles`, `crds.install`),
  not policies. Its sibling `global.networkPolicy.defaultDenyIngress` does render a
  `podSelector: {}` **Ingress** fence — in the release namespace, and off by default.
- Only **selected** pods are restricted. Once any policy selects a pod for `Egress`, that pod is
  deny-by-default; pods no policy selects fall through to `kns.<ns>`, which is allow-all in both
  directions in all 18 namespaces. **That fall-through is the thing to close, not a reason to leave
  it open** — the per-pod shape tightens named targets, and a namespace-wide fence is the curtain
  those named targets are holes in. Rule of thumb: `network/firewalls/README.md`.
- Staging previews (`StagedKubernetesNetworkPolicy` → `policies.pending`) only show where the
  staged policy is the **deciding** one: with a permissive netpol already in place the union
  means nothing is previewed. Nothing in the repo stages policies today.

## Traps that cost real time

- **A Helm hook Job's pods carry only the Job controller's labels** (`job-name`, …), never the
  chart's `app.kubernetes.io/name`. A pod-selector allow-list keyed on the app label misses them,
  and a `wait`-ing release turns it into a five-minute stall instead of a visible error (media's
  NGF cert-generator, 2026-09-16). Any pod-scoped policy must special-case Job traffic.
- **DNS failure looks exactly like a broken application**, so `UDP+TCP/53` to
  `kube-system`/`k8s-app=kube-dns` is unconditional in the module. A pod's own queries are its
  traffic; kube-dns's upstream lookups are kube-dns's.
- **A deferred read inside a module makes its consumer's plan a lie.** With a module-level
  `depends_on` covering a pending change, a `data` read inside that module defers, the plan's `to`
  block count becomes a guess, and the apply dies with
  `Provider produced inconsistent final plan ... block count changed from 1 to 2`. Fix used before:
  read in the **stack root** and pass values down; never hardcode control-plane IPs.
  `firewalls/egress/data.tf` reads the `kubernetes` Service and its Endpoints whenever
  `allow_k8s_api = true`, so the trap is live again — a caller that grows a `depends_on` over a
  pending change is the shape to watch.
- **`calicoctl` on PATH is 3.32.0 vs cluster v3.32.2 → refuses to run** (verified 2026-09-17).
  Pass `--allow-version-mismatch` on every call; the env var does not work.
- **RBAC a chart ships is not traffic a pod makes, and a socket table is not a startup log.** Two
  failure directions, both real: a chart can bind a `pods` CRUD ClusterRole to an SA nothing uses
  (SeaweedFS, 2026-09-17 — zero 6443 sockets in master/volume/filer), and a pod can be an API client
  with no long-lived connection at all (the CSI `driver-registrar`, which creates CRDs once at
  startup). Whisker cannot arbitrate either: watches are never emitted, and the dial it does record
  reads as `<node IP>:6443` on `PRIVATE NETWORK`, not as an API peer. Decide from the sidecar's verbs
  *and* a live `/proc/net/tcp` read (`.clinedocs/flow-logs.md`), and when the two disagree, believe the
  verbs — a denied write-once call is a broken controller that a quiet flow window will not show.
- **Host-network pods are outside pod policy entirely** (ls-config: `blender`'s mDNS advertiser,
  `calico-node`/`calico-typha`, `metallb-speaker`, `tigera-operator`, the kubeadm control-plane
  pods, `node-exporter`, `smartctl`). They will never appear in a guest list, and no policy
  restricts them.
- **A node's host network reaches a pod as two different addresses, and the apiserver is the second one.**
  Same-node host → pod arrives from the node's `InternalIP` (kubelet probes). Cross-node host → pod is
  MASQUERADEd on the way out of the *sending* node's `tunl0`, so the pod sees that node's Calico IPIP
  tunnel address — `projectcalico.org/IPv4IPIPTunnelAddr`, an address inside the pod CIDR that belongs to
  no namespace. Measured 2026-09-17 on `cert-manager-webhook` while adding an ingress curtain: the SYN
  left k8smaster as `10.244.16.128.56209 > 10.244.7.112.10250` inside `192.168.0.74 > 192.168.0.93`,
  where `10.244.16.128` is k8smaster's tunnel address and *not* its InternalIP; an `InternalIP`-only
  allow dropped it and the API answered
  `failed calling webhook "webhook.cert-manager.io": context deadline exceeded`. Whisker records such a
  source as `PRIVATE NETWORK` with no IP anywhere in the record, so the capture is the only way to see
  it: `firewalls/ingress` now reads the annotation alongside `InternalIP`. The same shape governs every
  apiserver → pod webhook (admission, conversion, aggregation) and any future curtain in front of one.
