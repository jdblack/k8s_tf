### Calico / NetworkPolicy invariants
Non-obvious and expensive to get wrong. Per-module detail in `modules/network/firewalls/*/README.md`.

 - **Calico evaluates egress policy POST-DNAT.** Allow rules must match the *endpoint* IP, not
   the Service ClusterIP -- so the k8s-API / DNS carve-outs track live endpoints.
 - **k8s NetworkPolicies only UNION.** An operator-shipped netpol cannot be tightened by
   adding one. tigera's `goldmane` netpol allows *any* source on 7443; unfixable from TF.
 - **A pod always accepts its own node's traffic, but the apiserver calls webhooks /
   aggregation endpoints from a REMOTE node** -> those paths need the node CIDR in the allow
   list. Same reason `etp=Cluster` LBs (blender samba, wg) break under a firewall while
   `etp=Local` (media, both gateways) pass.
 - **Staged policies only preview where the staged one is the *deciding* policy.** A namespace
   that already has a permissive netpol just unions and previews nothing.
 - calicoctl is on PATH but is **3.32.0 vs cluster 3.31.2, so it refuses to run**. Pass
   `--allow-version-mismatch` on every call -- the `CALICOCTL_ALLOW_VERSION_MISMATCH` env var does NOT work.
