# TODO

Known issues found during the 2026-08-29 cleanup review.
These are NOT state-preserving fixes - they change deployed behavior, so plan
and review each with `tofu plan` before applying.

## Gateway API migration — pilot: `media-private` (ACTIVE)

**Goal:** replace the `media-private` nginx-ingress controller (media ns, ingress
class `media-private`, MetalLB IP `192.168.0.106`) with **NGINX Gateway Fabric
(NGF) + Gateway API**. Pilot scope = the 6 media apps ONLY. The `public`,
`private`, and `internal` controllers are OUT OF SCOPE for now.

**Decision (2026-08-30):** NGF **v2.6.7**
- chart: `oci://ghcr.io/nginx/charts/nginx-gateway-fabric` (2.6.7)
- GatewayClass: `nginx` (controller `gateway.nginx.org/nginx-gateway-controller`)
- control plane ns: `nginx-gateway`; K8s `v1.35.6` OK (needs 1.31+)
- later benefit: NGF policies cover ollama's `nginx.org/lb-method: least_conn`
  (`UpstreamSettingsPolicy`), proxy timeouts (`ProxySettingsPolicy`), body size
  (`ClientSettingsPolicy`) — all `gateway.nginx.org/v1alpha1`.

### Apps in scope

| app | host | backend svc:port | new cert secret |
|---|---|---|---|
| sonarr | sonarr.vn.linuxguru.net | sonarr:80 | gw-cert-sonarr.vn.linuxguru.net |
| radarr | radarr.vn.linuxguru.net | radarr:80 | gw-cert-radarr.vn.linuxguru.net |
| bazarr | bazarr.vn.linuxguru.net | bazarr:80 | gw-cert-bazarr.vn.linuxguru.net |
| prowlarr | prowlarr.vn.linuxguru.net | prowlarr:80 | gw-cert-prowlarr.vn.linuxguru.net |
| qbittorrent | qbittorrent.vn.linuxguru.net | qbittorrent:8080 (webui) | gw-cert-qbittorrent.vn.linuxguru.net |
| threadfin | threadfin.vn.linuxguru.net | threadfin-svc:34400 | gw-cert-threadfin.vn.linuxguru.net |

Issuer for all: `linuxguru-ca` (media maps `cert_authorities.private`).

### Phase 0 — prep / safety (DONE)
- [x] `terraform state pull` for `stacks/core` and `stacks/mantle` → backup
- [x] baseline: 6 A records → `192.168.0.106`; shim cert secret names recorded

### Phase 1 — WIPE: controller + Ingresses removed (DONE 2026-08-30)
- [x] removed chart `ingress = {...}` blocks: `modules/media/{sonarr,radarr,bazarr,prowlarr}/locals.tf`
- [x] removed `kubernetes_ingress_v1`: `modules/media/{qbittorrent,threadfin}/service.tf`
- [x] deleted media controller: `modules/media/network.tf` (`helm_release.ingress_internal`)
      → `192.168.0.106` freed; IngressClass + webhook + SA gone
- [x] prowlarr ingress pinned OFF explicitly (`ingress.enabled=false` — see gotcha)
- [x] verified: only `plex` ingress remains in media; `.106` free; helm release gone

### Phase 2 — dangling cleanup (DONE 2026-08-30)
- [x] shim GC'd old Certificates; deleted leftover `cert-*` secrets (all 6 gone)
- [x] deleted stray legacy `cert-radarr.linuxguru.net`
- [x] deleted lingering `cert-prowlarr.vn.linuxguru.net` secret
- [x] sweep: no `media-private` deployments/services/SAs/roles/webhooks remain
      (only `cert-plex.linuxguru.net` kept — still used by the plex ingress)

### Phase 3 — build the new gateway (DONE 2026-08-30)
- [x] Gateway API standard CRDs (NGF-pinned): `kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | kubectl apply --server-side -f -`
- [x] NGF CRDs: `kubectl apply --server-side --force-conflicts -f .../v2.6.7/deploy/crds.yaml`
      (NOTE: client-side apply failed on `nginxproxies` — annotation too long; must use --server-side)
- [x] new `modules/gateway/` module wired into `stacks/core/core.tf`:
      ns `nginx-gateway` + `helm_release` ngf (oci chart 2.6.7, 1 replica,
      **version pinned in TF**, `nginx.service.loadBalancerIP = 192.168.0.106`)
- [x] `Gateway media-private` (ns `nginx-gateway`, class `nginx`):
      - `:80` HTTP listener, hostname `*.vn.linuxguru.net`
      - `:443` × 6 HTTPS listeners (one per host, SNI), each `certificateRefs` → its gw-cert secret
      - **`allowedRoutes` is PER-LISTENER** (default = Same-ns only): set
        `namespaces.from: Selector` → `kubernetes.io/metadata.name=media` on EVERY listener
- [x] 6× `Certificate` **in `nginx-gateway` ns** (NOT media): `gw-cert-<host>`, issuer
      `linuxguru-ca`, via `kubectl_manifest` in the core/gateway module — replaced in
      Phase 3b by cert-manager gateway-shim auto-provisioning
- [x] 7× `HTTPRoute` in `media` ns (`kubernetes_manifest` in `modules/media/routes.tf`):
      - 6 app routes: `parentRefs → Gateway media-private + sectionName: <host's https listener>`,
        hostnames, backendRefs (ports in table above)
      - 1 `redirect-http` route: hostnames `*.vn.linuxguru.net` on the `:80` listener,
        `filters: [requestRedirect {scheme: https, statusCode: 301}]`
- [x] data plane Service `media-private-nginx` took `.106` (DNS untouched)

### Phase 3b — certs auto-provisioned by cert-manager gateway-shim (DONE 2026-08-30)
- [x] cert-manager helm: `config.enableGatewayAPI: true` (the `gateway-shim` controller is
      disabled by default; `ExperimentalGatewayAPISupport` feature gate is default-on in 1.16)
- [x] `Gateway media-private` annotated `cert-manager.io/cluster-issuer: linuxguru-ca` (+ explicit
      `tls.mode: Terminate`); the shim creates a `Certificate` per listener named after
      `certificateRefs` (`gw-cert-<host>`) in `nginx-gateway`, owned by the Gateway →
      auto create/renew/GC (same declarative pattern as the old ingress annotations)
- [x] removed `modules/gateway/certificates.tf`; old tf-owned Certificates destroyed on apply, shim
      recreated identical ones (brief private-CA reissue, no manual steps)
- [x] `module.cert_man` now `depends_on [module.gateway]` so the Gateway API CRDs exist before
      the shim starts (fresh-rebuild ordering, fully tofu-managed)

### Phase 3c — per-app ownership via ListenerSet (DONE 2026-08-30)
- [x] NGF v2.6.7 supports `ListenerSet` (added in 2.6.0); the NGF-pinned Gateway API
      standard CRD bundle includes `listenersets.gateway.networking.k8s.io/v1`
- [x] `Gateway media-private` is now generic: only the shared `:80` HTTP listener
      (HTTP->HTTPS redirect) + `spec.allowedListeners` selector opting into
      ListenerSets from `media` — no per-app listeners, certs, or annotations
      (supersedes the Phase 3 / 3b design)
- [x] each media app module (`modules/media/<app>/expose.tf`) declares its own:
      - `ListenerSet` (media ns, parentRef → Gateway media-private): its HTTPS
        listener (hostname `<app>.<domain>`, port 443, mode Terminate,
        certificateRefs → `cert-<host>`)
      - `Certificate` `cert-<host>` (media ns, issuer `linuxguru-ca`) — explicit
        resource, because cert-manager 1.16 has no ListenerSet shim yet
      - `HTTPRoute` (media ns) with `parentRef: {kind: ListenerSet, name: <app>}`
        + sectionName, backendRef → service:port
- [x] NGF resolves ListenerSet cert secrets in the ListenerSet namespace (media)
      — no ReferenceGrant needed
- [x] old `gw-cert-*` certs removed; canonical `cert-<host>` names restored in media

### Phase 4 — verify (DONE 2026-08-30)
- [x] Gateway Accepted + Programmed=True; all 7 HTTPRoutes Accepted + ResolvedRefs=True;
      all 6 gw-cert Certificates Ready
- [x] `curl https://<host>` × 6 → sonarr 401, radarr 302, bazarr 200, prowlarr 302,
      qbittorrent 200, threadfin 200 (all app-normal); `http://` → 301 redirect
- [x] TLS SAN = host, issuer = linuxguru-ca; DNS records still point at `.106`
- [x] keep `--source=ingress` (other controllers still need it)

### Phase 5 — follow-ups
- [x] `gw-cert-*` → `cert-*` canonical names restored in `media` (Phase 3c)
- [ ] metrics: nginx-ingress media metrics gone; add NGF control-plane/data-plane scrape
- [ ] later pilots: `internal` (ollama → NGF policies), then `private`, then `public`

### Phase 6 — close media egress trampoline (DONE 2026-08-30)
- [x] **vuln found (proved with exec tests from `media/utility`):** egress was
      `0.0.0.0/0 except 10.0.0.0/8`, so node IPs + LAN (`192.168.0.0/16`) were
      reachable. kube-proxy SNATs nodePort/remote-backend service traffic, which
      **bypasses** pod egress policy → a compromised media pod could hit
      `nodeIP:32015` with `Host: harbor.vn.linuxguru.net` (got `200`) and pivot
      to every private-controller service (harbor, argo-cd, auth, grafana, …).
- [x] fix: `blocked_egress_cidrs` var in `basic_internet` defaults to all RFC1918
      (+ `169.254.0.0/16`) in the internet rule's `except`. Media egress is now:
      same-ns + kube-dns + public internet ONLY. Ingress left open (intentional).
- [x] `egress_allow_ip_blocks` var added for carve-outs (e.g. a specific LAN
      tuner/NAS for threadfin) — none configured yet.
- [x] verified post-apply: harbor/argo via nodePort `000`; node IPs (10250/6443/22/9100)
      + router blocked; internet/DNS/same-ns OK; all 6 gateway routes + plex unchanged;
      media pods Ready.
- [ ] NOTE: apiserver ClusterIP `10.96.0.1` may still be reachable from media via
      the kube-proxy SNAT bypass (backend = master node IP); RBAC-gated, accepted
      for now. Killing it needs host-endpoints or egress deny — deferred.

### Gotchas
- **CRD reproducibility (FIXED 2026-08-30):** the Gateway API CRDs were
  originally installed via a one-off kubectl. They're now bootstrapped by
  `terraform_data.gateway_api_crds` (local-exec, idempotent) in
  `modules/gateway/crds.tf` so `tofu apply` of core recreates them. The NGF
  chart ships its own CRDs (`crds/` dir) so those were never a gap. On a bare
  cluster, apply core first (or `-target` the terraform_data) so CRDs exist
  before mantle plans its HTTPRoutes.
- **cert secret namespace:** Gateway listener `certificateRefs` → Secrets MUST be in
  the Gateway's namespace (`nginx-gateway`); cross-ns requires ReferenceGrant.
  ListenerSet listeners instead resolve `certificateRefs` in the ListenerSet's namespace
  (media) — that is why each app's cert lives in its own namespace with no ReferenceGrant.
- **HTTPRoute parent for ListenerSet listeners is the ListenerSet**, not the Gateway:
  `parentRefs: [{kind: ListenerSet, name: <app>, namespace: media, sectionName: <app>}]`
  (attaching via the Gateway gives `NoMatchingParent`).
- **per-app certs are explicit `Certificate` resources** in each app module
  (`modules/media/<app>/expose.tf`), named `cert-<host>`, matching the ListenerSet
  `certificateRefs`. cert-manager 1.16 has no ListenerSet shim (exists only in master),
  so they are declared directly rather than auto-provisioned.
- **helm empty-values trap (LEARNED on prowlarr):** an empty `helm_values = {}` does
  NOT clear a release's prior user-supplied values — the hashicorp/helm provider
  skips empty values and helm reuses the old ones. To remove a values block, pass an
  explicit override (e.g. `ingress.enabled = false`). Sonarr/radarr/bazarr were fine
  because their values stayed non-empty.
- **`allowedRoutes` is per-listener** on the Gateway; the default is Same-namespace
  only → EVERY listener needs the media namespace Selector.
- **`sectionName` on every app-route `parentRefs`** → prevents ambiguity across the
  7 listeners.
- **apply order:** `stacks/core` FIRST (CRDs → NGF → Gateway → certs), then
  `stacks/mantle` (HTTPRoutes via `kubernetes_manifest` need the Gateway API CRDs
  present; CRDs are cluster-wide + idempotent, installed via kubectl).
- **`.106` pin is one-shot:** `nginx.service.loadBalancerIP` is applied when NGF
  creates the data plane Service; changing it later makes NGF recreate the Service.
- **rollback:** the old controller is GONE — rollback = re-apply the Phase 0 state
  backups (restore `modules/media` from git + `tofu apply`), then delete NGF/Gateway.
- **backendRef ports** must be real service ports: sonarr/radarr/bazarr/prowlarr=80,
  qbittorrent=8080, threadfin-svc=34400.
- **qbittorrent direct LB** (`.105`, webui+torrent ports) stays untouched.
- **old `.106` DNS records** stay exactly as-is (external-dns `upsert-only` won't touch
  them, and they point at the right IP) — no stale-record problem in this pilot.

