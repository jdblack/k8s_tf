### Calico / NetworkPolicy invariants

**Status 2026-09-16: this repo has no NetworkPolicy layer.** The `firewalls/` library and
every per-app netpol were deleted so that everything can talk to everything; the only policy
left anywhere in the tree is `modules/network/whisker/tier.tf` (Calico CRs, needed to work
*around* the operator's own tier — see below). The facts here are what a rebuild must not
re-learn; they are all still live for the policies the tigera-operator ships itself.

 - **Calico evaluates egress policy POST-DNAT.** Allow rules must match the *endpoint* IP and
   port, not the Service ClusterIP (`authentik-server:80` is really pod `:9000`; the
   k8s-API carve-out tracked live `kubernetes` Endpoints IPs, not `10.96.0.1`).
 - **k8s NetworkPolicies only UNION.** An operator-shipped netpol cannot be tightened by
   adding one. tigera's `goldmane` netpol allows *any* source on 7443; unfixable from TF.
 - **Tiers are ordered, and an earlier tier's end-of-tier DROP pre-empts every later tier.**
   Kubernetes NetworkPolicies compile into the `default` tier (`order: 1000000`); Calico
   `NetworkPolicy` CRs live wherever `spec.tier` says. tigera-operator **v3.32.2 moved its
   own rules into a new tier `calico-system` (`order: 100`, `defaultAction: Deny`)** holding
   `calico-system.default-deny` (`selector: k8s-app != 'calico-apiserver'`, `types: [Ingress,
   Egress]`, i.e. no rules at all) plus holes for its own components (`goldmane`, `whisker`,
   `apiserver-access`, `kube-controller-access`, `kube-system/calico-system.cluster-dns`).
   Consequence: **every non-Calico pod in `calico-system` has inbound and outbound traffic
   dropped, and no k8s NetworkPolicy can change that** — however it is written. Verified in
   iptables: `cali-fw-<iface>` runs `Start of tier calico-system` -> ... -> `End of tier
   calico-system. Drop if no policies passed packet -j DROP` -> only then `Start of tier
   default`. Empirically: a plain `busybox` pod in `calico-system` cannot resolve DNS, ping
   CoreDNS, or ping the LAN gateway, while the same pod in `default` on the same node is
   fine. **Only a Calico `NetworkPolicy`/`GlobalNetworkPolicy` CR in tier `calico-system`
   can allow anything there.** The pattern is used in `modules/network/whisker/tier.tf` (3
   pod-scoped CRs, applied by `mantle`). Keep such CRs pod-scoped -- a `selector` with no
   `namespaceSelector` means "this namespace", and the `namespaceSelector` is
   `projectcalico.org/name == '<ns>'` (NOT `createIndex`/`kubernetes.io/metadata.name`,
   which is the k8s-netpol key). `spec.tier` is the namespace name here only because the
   operator names its tier after the namespace. **Set an explicit `order`**: inside a tier,
   policies run lowest-`order`-first, an `Allow`/`Deny` ends evaluation (only `Pass`
   continues), and an unset `order` is lowest precedence, i.e. evaluated last (stated for
   Tier `order` in the docs; Felix treats a policy's unset `order` the same way -- verified
   here, not documented). That ordering is why the pattern works at all: the operator's own
   holes are `order: 1` and its `default-deny` / `whisker` deny-alls are **unset**, so the
   whisker tier CRs at `order: 10` win their hops while goldmane's `order: 1` hole keeps
   goldmane alive -- both confirmed as the deciding policy in flow records, not inferred. A
   CR referencing a tier that does not exist yet is rejected at admission, so `core` must
   have applied the operator before `mantle` creates these (documented apply order covers
   it).
 - **A pod always accepts its own node's traffic, but the apiserver calls webhooks /
   aggregation endpoints from a REMOTE node** -> those paths need the node CIDR in the allow
   list. Same reason `etp=Cluster` LBs (blender samba, wg) break under a firewall while
   `etp=Local` (media, both gateways) pass. Only matters again if the layer is rebuilt.
 - **A Job's pods carry ONLY the Job controller's labels** (`job-name`,
   `batch.kubernetes.io/job-name`, `controller-uid`) -- never the labels the chart set on its
   own Deployments. So a `pod_selector` aimed at an app's controller silently misses every
   chart hook, and since one NetworkPolicy cannot OR two selectors, each hook needs its OWN
   policy. Cost of getting this wrong (media, 2026-09-16): NGF's `pre-install`/`pre-upgrade`
   `cert-generator` Job dies on `dial tcp 10.96.0.1:443: i/o timeout`, exhausts
   `backoffLimit`, and helm's `wait` burns the release's whole `timeout` -- a hang, not a
   fast error.
 - **Staged policies only preview where the staged one is the *deciding* policy.** A namespace
   that already has a permissive netpol just unions and previews nothing. Nothing stages a
   policy now.
 - calicoctl is on PATH but is **3.32.0 vs cluster 3.32.2, so it refuses to run**. Pass
   `--allow-version-mismatch` on every call -- the `CALICOCTL_ALLOW_VERSION_MISMATCH` env var does NOT work.
