# System Patterns — architecture and the patterns you must follow

## Layout

```
stacks/{core,mantle,apps}/      # root modules, applied in that order
modules/
├── network/        Calico, MetalLB, external-dns, shared NGF gateways,
│                   Gateway API CRD bootstrap, wireguard, whisker
│   ├── firewalls/  NetworkPolicy library (basic_internet, limited_ingress,
│   │               allow_api) over one renderer (policy)
│   ├── gateway/    one NGF instance per call; submodules listener_set,
│   │               http_route, expose (= listener_set + http_route)
│   └── dns/route53_record/
├── storage/        Longhorn (+netpols, VolumeSnapshotClasses), SeaweedFS
│                   (helm, CSI, listeners, dashboard), seaweedfs_admin
├── cert_manager/   cert-manager + linuxguru-ca + letsencrypt (Route53 DNS-01)
├── auth/authentik/ core, proxy_app, outpost, oidc_provider
├── monitoring/     prometheus (kube-prometheus-stack), grafana_oidc,
│                   metrics_server, smartctl
├── harbor/         core (release+listener), mantle (projects+OIDC)
├── argo/           core (Argo CD), mantle (SSO/deploy key, workflows, events),
│                   aoa_deployment (app-of-apps generator, apps stack)
├── media/          arr stack + plex + qbittorrent + media-private gateway
├── blender/        Samba on the LAN + mDNS/Bonjour advertiser
└── vaultwarden/    Bitwarden-compatible server + its Route53 A record
```

## Pattern: each app owns its exposure

`modules/<mod>/listener.tf` calls `network/gateway/expose`, which renders the
app's HTTPS `ListenerSet` (annotated with the cert-manager issuer, so
`cert-<fqdn>` is auto-provisioned) plus an `HTTPRoute` (host → Service) and any
cross-namespace `ReferenceGrant`. Charts that render their own route
(harbor, authentik, argo-cd) omit `backend_name` and get the listener only.
Outpost-fronted apps point `route_name = "<app>-auth"` at the outpost service.

- Certs and secrets live with the services that use them; no hand-written
  `Certificate` anywhere.
- `hostname` overrides for sub-subdomains (`admin.seaweedfs.<domain>`).

## Pattern: firewalls compose (NetworkPolicies UNION)

- Never assume one policy per namespace. `limited_ingress` (ingress guest list)
  + `basic_internet` (egress) = full posture for a gateway-fronted app;
  `basic_internet` (API off) + `allow_api` = namespace lockdown with one
  pod-scoped API exception.
- All presets build rule objects and hand them to `firewalls/policy`, the single
  renderer. Everything renders a typed `kubernetes_network_policy_v1` so drift
  is visible to `plan` (a kubectl-managed netpol once hid a live edit).
- `basic_internet.allow_to_k8sapi` is namespace-wide convenience;
  `allow_api` is the pod-scoped lockdown. **Prefer `allow_api`.**
- Staged rollout (the intended method for the remaining namespaces):
  render a `StagedKubernetesNetworkPolicy` (`crd.projectcalico.org/v1`) — same
  rules, NOT enforced — and Calico records would-be denies as `pendingPolicies`
  in the flow logs. **NOT IMPLEMENTED YET in Terraform**: there is no `staged`
  variable in `firewalls/policy` or `limited_ingress` (grep-verified 2026-09-14).
  The mechanism itself was proven by hand on `argo`. Adding the flag is the first
  task of the rollout.
  **Staged policies only preview where the staged one is the deciding policy**;
  a namespace with an existing permissive netpol just unions and previews
  nothing.
- Guest lists must be derived from **real flow data** (Goldmane/Whisker), not
  guesses. See `.clinedocs/flow-logs.md` and `.clinedocs/calico-netpols.md`.

## Hard Calico invariants (expensive to get wrong)

- Egress is evaluated **POST-DNAT** → allow rules match the *endpoint* IP.
- k8s netpols only UNION → an operator-shipped netpol cannot be tightened.
  tigera's `goldmane` allows any source on 7443; unfixable from TF.
- The apiserver calls webhooks/aggregation from a **remote node** → those paths
  need the **node CIDR** in the guest list. Same reason `etp=Cluster`
  LoadBalancers (blender samba, WG) break under a firewall while `etp=Local`
  (media, both gateways) pass.
- `calicoctl` on PATH is **3.32.0 vs cluster 3.31.2 → refuses to run**. Pass
  `--allow-version-mismatch` on every call (the env var does NOT work).

## Other conventions

- **Terraform owns structure (groups, apps, bindings); the UI owns people.**
  Rebuild needs group members re-added by hand.
- **Pin charts.** Pinned: MetalLB 0.16.1, NGF 2.6.7, kube-prometheus-stack
  90.1.1, Longhorn 1.12.1, SeaweedFS 4.40.0 + CSI 0.2.35, authentik 2025.10.3,
  wireguard-operator 0.3.0, media charts. **Unpinned/float:** cert-manager,
  Harbor, external-dns, snapshot-controller, metrics-server,
  prometheus-smartctl-exporter, argo-cd, argo-events. Bump one at a time.
- **Dashboards ship from the owning module** as `grafana_dashboard: "1"`
  ConfigMaps (mirrors ServiceMonitors); Grafana keys them by `uid`.
- **`checksum/config`** on pod templates when a Secret/ConfigMap should roll the
  pod (vaultwarden, blender mdns).
- `.clinedocs/` holds deep, non-obvious operational notes (flow queries, netpol
  invariants) — load only when working that area.
