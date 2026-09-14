# Progress

## What works (verified live unless noted)

- **Core platform** — Calico (tigera-operator), MetalLB (L2), external-dns
  (rfc2136 → bind9, authoritative for `vn.linuxguru.net` only), Longhorn,
  SeaweedFS + CSI, cert-manager (pinned `v1.21.1`; **`letsencrypt` DNS-01 with the
  zone pinned signs all 17 hosts** as of 2026-09-15 — no workload injects a
  private CA any more, and `~/.ssl/ca.crt` is not needed by any client; the
  `linuxguru-ca` issuer still exists but signs nothing),
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
- **apps stack** — ArgoCD `AppProject` + app-of-apps `Application` for `ai`
  (`ollama` and `corsless` live from the external deployments dir;
  `llm-embedder` repointed and rebuilding).

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
- ~~**Let's Encrypt for the remaining `.vn` hosts.**~~ **DONE 2026-09-15: all 17
  hosts are on `letsencrypt`** and every CA injection was deleted in the same
  apply as the last four flips (`auth.vn`, `harbor`, `grafana`, `argo-wf`). See
  `activeContext.md` for the verification evidence (SSO hand-offs, in-cluster
  trust probe, cluster-wide CA sweep).
- **Retire the CA** (the migration's last step): drop the `linuxguru-ca`
  ClusterIssuer + the `kube-certificates/linuxguru-ca` Secret + the
  `default/linuxguru-ca` ConfigMap + the module's `ca_certfile`/`ca_keyfile`
  `file()` inputs, then `~/.ssl/ca.crt` and the node trust store in
  `initial_setup.yml` (k8s repo). Nothing is broken while it lingers — but
  `~/.ssl/ca.*` must keep existing or `tofu plan` fails.
- **Nothing scrapes cert-manager.** No `ServiceMonitor`, no expiry
  `PrometheusRule`, so a failed renewal stays invisible until the cert expires
  (~30 days of slack at 2/3 lifetime). Cheap win: ServiceMonitor on
  `kube-certificates/cert-manager:9402` + a
  `certmanager_certificate_expiration_timestamp_seconds < 21d` alert.
- **`corsless` / `llm-embedder` are still dead apps** — no longer for TLS
  reasons. Their Helm repos (`linuxguru/corsless-helm`, `linuxguru/llm-embedder-chart`)
  return `404: repository not found` from Harbor, so the charts were never pushed
  or were removed. Only `ollama` is live from that external app-of-apps dir.
  **RESOLVED 2026-09-15**: it was a registry split-brain — Argo, the values and
  TF all named Harbor project `linuxguru` while the `build` scripts pushed to
  `library`, and `robot$jblack` can only push to `library`. Everything is
  repointed at `library`, helm's credential store is seeded, both charts render
  `extraObjects`, and `library/corsless-helm:0.0.26` is published. `corsless` is
  **verified serving** (stock-trust TLS, app answers; cert re-issued from the old
  CA to `letsencrypt`). `llm-embedder` only needs its image to finish
  building/publishing — see `activeContext.md` for the full bug chain.
- ~~Orphan ClusterIssuer `letsencrypt-http`~~ — HTTP-01/ingress-nginx leftover,
  in no `.tf` and referenced by no Certificate. **Deleted 2026-09-15**, along with
  its `letsencrypt-http-key` account key.
- **Whisker UI through the proxy** — unconfirmed.
- **authentik group membership** is hand-managed → a from-scratch rebuild needs
  members re-added by hand.
- **One-time, hand-run per-app config** that a rebuild must redo:
  arr apps `AuthenticationMethod = External`; qBittorrent pod-CIDR WebUI
  whitelist + hard pod kill; vaultwarden first-account bootstrap
  (`signups_allowed = true` → register → back to `false`).
- **Chart pinning debt** — Harbor, external-dns,
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
- `.vn` hosts move to Let's Encrypt on demand via a per-app `cert_issuers`
  override (`modules/media`) or the module's `cert_issuer`/`cert_issuers`
  argument: DNS-01 needs no inbound reachability and no new Route53 zone.
  2026-09-15 went from one host (`sonarr`) to **12 of 17 certs**, with
  `modules/media`'s default flipped to the public issuer and a 9-host batch
  applied in a single pass — proving the "one host at a time" caution was
  unnecessarily conservative for leaf-only hosts. The same day finished the job
  (17 of 17): the last four flips had to ride in the **same apply** as the
  deletions of their CA trust material, because the *replacing* knobs (Grafana's
  `SSL_CERT_FILE`, Workflows' bundle subPath mount) break their app's SSO if
  separated from the flip in either direction. The `ca_name` split that was
  planned for that turned out to be unnecessary — deleting the wiring in the same
  apply is what removes the coupling.
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
