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
   down (`allow_api` + `basic_internet` both take it; `cert_manager` and `authentik` do this).
   Forewarned in a plan by `will be read during apply` / `depends on a resource or a module
   with changes pending`. **Do NOT** "fix" it by hardcoding control-plane IPs: the endpoint
   entry is the peer that actually authorizes API egress, so a re-IP becomes a silent 6443 deny.
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
