# Progress

## What works (verified live unless noted)

- **Core platform** — Calico (tigera-operator), MetalLB (L2), external-dns
  (rfc2136 → bind9, authoritative for `vn.linuxguru.net` only), Longhorn,
  SeaweedFS + CSI, cert-manager (`linuxguru-ca` + `letsencrypt` DNS-01),
  authentik, kube-prometheus-stack + Grafana SSO, Harbor, Argo CD,
  WireGuard operator, Gateway API CRDs + shared NGF gateways.
- **Gateway/exposure model** — `gateway/expose` used by every app; certs
  auto-provisioned from the ListenerSet annotation. No hand-written
  `Certificate`s. Public/private gateway data planes pinned to
  `192.168.0.101`/`.100`.
- **mantle workloads** — media (sonarr/radarr/prowlarr/bazarr/plex/qbittorrent,
  all outpost-fronted except the torrent port), blender (Samba + mDNS Bonjour
  advertiser macOS Finder needs), whisker (flow-log UI, SSO-gated),
  seaweedfs-admin (SSO-gated), Grafana/Harbor/Argo OIDC + deploy keys.
- **vaultwarden** — deployment + PVC + Service + Route53 A record, publicly
  trusted cert on a private gateway, admin panel disabled, nightly Longhorn
  snapshot. Drift test documented and passing (2026-09-14).
- **Firewall library** — `policy` renderer + `basic_internet`,
  `limited_ingress`, `allow_api`. Media namespace locked down (2026-09-12).
  Staged/preview mechanism proven on `argo`.
- **apps stack** — ArgoCD `AppProject` + app-of-apps `Application` for `ai`.

## What's left / open

- **Namespace ingress rollout** for every namespace except `media` (see
  `activeContext.md` and `TODO.md`). This is the main thread of work.
- **vaultwarden off-cluster backups** (Longhorn `backupTarget` → SeaweedFS S3).
- **vaultwarden has nothing to scrape** — 1.37.3 dropped its metrics build
  feature (no `/metrics`, no `PROMETHEUS_ENABLED`, only `GET /alive`), so the
  module ships no ServiceMonitor. Re-check upstream; if it returns, add
  `monitoring.tf` and add `monitoring` to the ingress guest list in
  `modules/vaultwarden/security.tf`.
- **Longhorn Grafana dashboard** not imported.
- **external-dns HTTPRoute-annotation publishing** unexplained for `.vn` names.
- **`route53.zoneid` → `hostedZoneID` fix** in `modules/cert_manager`.
- **Whisker UI through the proxy** — unconfirmed.
- **authentik group membership** is hand-managed → a from-scratch rebuild needs
  members re-added by hand.
- **One-time, hand-run per-app config** that a rebuild must redo:
  arr apps `AuthenticationMethod = External`; qBittorrent pod-CIDR WebUI
  whitelist + hard pod kill; vaultwarden first-account bootstrap
  (`signups_allowed = true` → register → back to `false`).
- **Chart pinning debt** — cert-manager, Harbor, external-dns,
  snapshot-controller, metrics-server, prometheus-smartctl-exporter, argo-cd,
  argo-events all float today.
- **Optional**: a `posture` wrapper so a namespace states egress+ingress in one
  call instead of 2-4 module calls (deferred until after the rollout).
- **Accepted risks**: `goldmane:7443` readable by any pod (unfixable from TF);
  media NodePort soft spot (`nodeIP:nodePort` bypass); `ollama` has no auth in
  front of it.

## Evolution of decisions worth knowing

- `allow_ingress` → renamed `limited_ingress` (2026-09) because the old name
  read like a blanket allow when it is a lockdown with a guest list. Docs/paths
  only — no resources moved, so no create/destroy.
- `namespace_only` is gone — replaced by `limited_ingress` with a one-namespace
  guest list, typed instead of `kubectl_manifest`.
- ntfy alerting was added and then removed (2026-09); Alertmanager runs stock
  `null`.
- The `modules/security/trivy` module was removed 2026-09; the `kube-security`
  namespace lingers in state only.
- WordPress deployments in `stacks/apps` were disabled when the cluster moved
  from ingress-nginx to Gateway API (they expect `ingress_class`); reviving them
  means porting to `gateway/expose` and using `letsencrypt`/`linuxguru-ca`
  (`letsencrypt-http` no longer exists).

## How to tell you're still on track

`tofu -chdir=stacks/<stack> plan` should be **empty** against a healthy cluster.
Any diff is either intended work or drift — never silence it with a targeted
apply.
