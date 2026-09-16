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

## Other conventions

- **Terraform owns structure (groups, apps, bindings); the UI owns people.**
  Rebuild needs group members re-added by hand.
- **Pin charts.** 
- **Dashboards ship from the owning module** as `grafana_dashboard: "1"`
  ConfigMaps (mirrors ServiceMonitors); Grafana keys them by `uid`.
- **`checksum/config`** on pod templates when a Secret/ConfigMap should roll the
  pod (vaultwarden, blender mdns).
- `.clinedocs/` holds deep, non-obvious operational notes (flow queries, netpol
  invariants) — load only when working that area.
