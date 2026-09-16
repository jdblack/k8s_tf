# System Patterns — architecture and the patterns you must follow

## Layout

```
stacks/{core,mantle,apps}/      # root modules, applied in that order
modules/
├── network/        Calico, MetalLB, external-dns, shared NGF gateways,
│                   Gateway API CRD bootstrap, wireguard, whisker
│   ├── gateway/    one NGF instance per call; submodules listener_set,
│   │               http_route, expose (= listener_set + http_route)
│   ├── whisker/    flow-log UI; tier.tf = the repo's ONLY network policy
│   └── dns/route53_record/
├── storage/        Longhorn (+VolumeSnapshotClasses), SeaweedFS
│                   (helm, CSI, listeners, dashboard), seaweedfs_admin
├── cert_manager/   cert-manager + linuxguru-ca + letsencrypt (Route53 DNS-01)
├── auth/authentik/ core, proxy_outpost, oidc_provider
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
- One host can move off the default issuer without moving its namespace: the shim
  re-issues in place because the Certificate is named after the listener's Secret.
- **One name for the issuer: `cert_authorities.default`** (tfvars; `letsencrypt`
  today). Every module takes a plain `cert_issuer` string and each of the ten call
  sites in core/mantle passes that key, so switching one host — or all of them —
  back to the CA is a value change, not a plumbing change. The `cert_issuers` maps
  (media per-app override, seaweedfs visibility-keyed) and `local.issuers` were
  deleted 2026-09-15.
- **No module injects a CA any more (2026-09-15).** All 19 hosts are on
  `letsencrypt`; the four that used to mount the private CA (`harbor`, `grafana`,
  `argo-wf`, `argo-cd`) validate authentik against the container's own public
  roots. Per-consumer injection checklist (Argo CD first) and the
  same-apply rule for bundle-replacing knobs: `modules/cert_manager/README.md`.
- **Apps deployed from the external `argo-linuxguru` repo (the `ai` project)
  own their exposure in their own chart values instead** — they aren't TF
  modules, so `gateway/expose` can't reach them. `extraObjects` in the
  Application's `valuesObject` carries the ListenerSet + `ReferenceGrant` +
  `HTTPRoute` (the `otwld/ollama-helm` convention); both local charts
  (`corsless-helm`, `llm-embedder-chart`) now ship
  `templates/extraObjects.yaml` to render it. Those charts publish to Harbor
  project **`library`** (`library/<app>` + `library/<chart>`), not `linuxguru`.
  ArgoCD reaches the charts through `argocd_repository.devops_helm`
  (`modules/argo/mantle/argo-cd/repositories.tf`), whose Terraform id **is the
  repo URL** and whose Secret lands as `argo/repo-<fnv32a(repo_url)>` — so
  changing the project in one place without the other shows up as a permanent
  `1 to add` in `tofu plan`, and hand-editing the Secret's `url` desyncs it.
- `hostname` overrides for sub-subdomains (`admin.seaweedfs.<domain>`).

## Pattern: no NetworkPolicy layer (deleted 2026-09-16)

There was a real one: `network/firewalls/{policy,basic_egress,limited_ingress}` —
typed `kubernetes_network_policy_v1` resources so `plan` saw drift, called from
every app module. It was deleted along with every per-app `security.tf` so that
any workload can reach any other. **Nothing enforces network policy here today**,
with one exception that is not a restriction but a prerequisite:
`modules/network/whisker/tier.tf` (Calico CRs in the operator's own tier — see
the invariants below).

If the layer is ever rebuilt:

- Start from `.clinedocs/calico-netpols.md` (conserved invariants: post-DNAT
  egress, netpols only UNION, tier ordering, the Job-label gotcha) and
  `.clinedocs/flow-logs.md` (how to read real traffic).
- Guest lists come from **real flow data** (Goldmane/Whisker), not guesses.
- Prefer a pod-scoped lockdown over a namespace-wide `allow_k8s_api`: the
  namespace-wide shape is the one a caller's `depends_on` can break.
- Staging worked (`StagedKubernetesNetworkPolicy` → `pendingPolicies` in the flow
  logs) but only previews where the staged policy is the **deciding** one — a
  namespace with a permissive netpol just unions and previews nothing.

## Hard Calico invariants (expensive to get wrong)

- Egress is evaluated **POST-DNAT** → allow rules match the *endpoint* IP.
- A module-level `depends_on` covers a module's **data sources**, and a deferred
  read makes its consumer's plan a lie: a policy that read the `kubernetes`
  Endpoints object *inside* the module planned a guessed peer count (ClusterIP
  only) and the apply died with `inconsistent final plan`. Fix was to read it in
  the **stack root** (`stacks/core/core.tf`) and pass the peer IPs down — never
  hardcode control-plane IPs. The netpol and that plumbing are gone (2026-09-16);
  the lesson applies to any provider-deferred read inside a module.
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
- **Pin charts.** Pinned: MetalLB 0.16.1, NGF 2.7.1, kube-prometheus-stack
  90.1.1, Longhorn 1.12.1, SeaweedFS 4.40.0 + CSI 0.2.35, authentik 2025.10.3,
  wireguard-operator 0.3.0, cert-manager v1.21.1, media charts.
  **Unpinned/float:** Harbor, external-dns, snapshot-controller, metrics-server,
  prometheus-smartctl-exporter, argo-cd, argo-events, plex (whose "repo" is a
  `raw.githubusercontent.com` gh-pages path, so a bump is also a check that the
  chart still resolves). Bump one at a time.
- **Dashboards ship from the owning module** as `grafana_dashboard: "1"`
  ConfigMaps (mirrors ServiceMonitors); Grafana keys them by `uid`.
- **`checksum/config`** on pod templates when a Secret/ConfigMap should roll the
  pod (vaultwarden, blender mdns).
- **Snapshots are cluster policy, joined by Volume-CR labels.** Longhorn matches a
  `RecurringJob` to a volume by `recurring-job-group.longhorn.io/<group>` on the
  **Volume CR** (`RecurringJob.spec` has `groups`; there is no volume list), so the
  labels are written once — `modules/storage/snapshot_labeler.tf` — and *no PVC
  carries them*: a PVC with those labels **replaces** its volume's entire group set
  instead of merging, silently de-enrolling it. Never list the `default` group in a
  job (every newly provisioned unlabelled volume lands in it), and re-run the
  labeler (`-replace` of one address) after deleting a job or moving a volume
  between tiers. Reverting a snapshot needs **maintenance mode**, because
  `spec.disableFrontend` is derived from the VolumeAttachment tickets and not from
  the Volume CR, and the manager API answers **in-cluster only**. Runbook with the
  verified commands: `modules/storage/disaster_recovery.md`.
- `.clinedocs/` holds deep, non-obvious operational notes (flow queries, netpol
  invariants) — load only when working that area.
