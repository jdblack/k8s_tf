### Calico / NetworkPolicy invariants
Non-obvious and expensive to get wrong. Per-module detail in `modules/network/firewalls/*/README.md`.

 - **Calico evaluates egress policy POST-DNAT.** Allow rules must match the *endpoint* IP, not
   the Service ClusterIP -- so the k8s-API / DNS carve-outs track live endpoints.
 - **`depends_on` on a module covers its DATA SOURCES too** -- and a data source deferred to
   apply time makes its consumer's plan a lie: the API carve-out then plans a *guessed*
   peer-block count (ClusterIP only, 1) while apply reads the real 2, and the apply dies with
   `Provider produced inconsistent final plan` (`spec.egress[1].to: block count changed from 1
   to 2`). So a firewall that reads the `kubernetes` Endpoints object must not sit under a
   module-level `depends_on`: read the endpoints in the STACK ROOT and pass `api_peer_ips`
   down (`basic_egress` takes it; `cert_manager`, `authentik` and `storage` do this).
   Forewarned in a plan by `will be read during apply` / `depends on a resource or a module
   with changes pending`. **Do NOT** "fix" it by hardcoding control-plane IPs: the endpoint
   entry is the peer that actually authorizes API egress, so a re-IP becomes a silent 6443 deny.
 - **k8s NetworkPolicies only UNION.** An operator-shipped netpol cannot be tightened by
   adding one. tigera's `goldmane` netpol allows *any* source on 7443; unfixable from TF.
 - **Tiers are ordered, and an earlier tier's end-of-tier DROP pre-empts every later tier.**
   Kubernetes NetworkPolicies compile into the `default` tier (`order: 1000000`); Calico
   `NetworkPolicy` CRs live wherever `spec.tier` says. tigera-operator **v3.32.2 moved its
   own rules into a new tier `calico-system` (`order: 100`, `defaultAction: Deny`)** holding
   `calico-system.default-deny` (`selector: k8s-app != 'calico-apiserver'`, `types: [Ingress,
   Egress]`, i.e. no rules at all) plus holes for its own components (`goldmane`, `whisker`,
   `apiserver-access`, `kube-controller-access`, `kube-system/calico-system.cluster-dns`).
   Consequence: **every non-Calico pod in `calico-system` now has inbound and outbound
   traffic dropped** -- and, because the `calico-system` tier is evaluated *before* `default`,
   **our own k8s NetworkPolicies for that namespace are inert** (they are compiled, and
   unreachable). Verified in iptables: `cali-fw-<iface>` runs `Start of tier calico-system` ->
   ... -> `End of tier calico-system. Drop if no policies passed packet -j DROP` -> only then
   `Start of tier default` (which holds `cali-po-_…` = `KubernetesNetworkPolicy
   calico-system/whisker-outpost-egress`). Empirically: a plain `busybox` pod in
   `calico-system` cannot resolve DNS, ping CoreDNS, or ping the LAN gateway, while the same
   pod in `default` on the same node is fine. **Only a Calico `NetworkPolicy`/`GlobalNetworkPolicy`
   CR in tier `calico-system` can allow anything there** -- a k8s netpol cannot, however it is
   written. First use of this pattern is `modules/network/whisker/tier.tf` (3 pod-scoped CRs,
   applied by `mantle`; it is the fix for whisker, broken by the same upgrade). Keep such CRs
   pod-scoped -- a `selector` with no `namespaceSelector` means "this namespace", and the
   `namespaceSelector` is `projectcalico.org/name == '<ns>'` (NOT `createIndex`/`kubernetes.io/metadata.name`,
   which is the k8s-netpol key). `spec.tier` is the namespace name here only because the operator
   names its tier after the namespace. **Set an explicit `order`**: inside a tier, policies run
   lowest-`order`-first, an `Allow`/`Deny` ends evaluation (only `Pass` continues), and an
   unset `order` is lowest precedence, i.e. evaluated last (stated for Tier `order` in the
   docs; Felix treats a policy's unset `order` the same way -- verified here, not documented).
   That ordering is why this pattern works at all: the operator's own holes are `order: 1` and
   its `default-deny` / `whisker` deny-alls are **unset**, so the whisker tier CRs at
   `order: 10` win their hops while goldmane's `order: 1` hole keeps goldmane alive -- both
   confirmed as the deciding policy in flow records, not inferred. A CR
   referencing a tier that does not exist yet is rejected at admission, so `core` must have
   applied the operator before `mantle` creates these (documented apply order covers it).
 - **A pod always accepts its own node's traffic, but the apiserver calls webhooks /
   aggregation endpoints from a REMOTE node** -> those paths need the node CIDR in the allow
   list. Same reason `etp=Cluster` LBs (blender samba, wg) break under a firewall while
   `etp=Local` (media, both gateways) pass.
 - **A Job's pods carry ONLY the Job controller's labels** (`job-name`,
   `batch.kubernetes.io/job-name`, `controller-uid`) -- never the labels the chart set on its
   own Deployments. So a `pod_selector` aimed at an app's controller silently misses every
   chart hook, and since one NetworkPolicy cannot OR two selectors, each hook needs its OWN
   policy. Cost of getting this wrong: NGF's `pre-install`/`pre-upgrade` `cert-generator` Job
   dies on `dial tcp 10.96.0.1:443: i/o timeout`, exhausts `backoffLimit`, and helm's `wait`
   burns the release's whole `timeout` -- a hang, not a fast error (media, 2026-09-16; see
   `modules/network/firewalls/basic_egress/README.md#hook-jobs-need-their-own-selector`).
 - **Staged policies only preview where the staged one is the *deciding* policy.** A namespace
   that already has a permissive netpol just unions and previews nothing.
 - calicoctl is on PATH but is **3.32.0 vs cluster 3.32.2, so it refuses to run**. Pass
   `--allow-version-mismatch` on every call -- the `CALICOCTL_ALLOW_VERSION_MISMATCH` env var does NOT work.
