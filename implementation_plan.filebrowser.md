# Implementation Plan

[Overview]
Land FileBrowser Quantum (`v2.0.9-beta`) as the `documents` namespace's shared-storage file browser, reachable at `docs.vn.linuxguru.net` through the shared `private` gateway, gated by native OIDC against a new authentik application `documents`.

Scope and context:

* New module `modules/documents` (namespace `documents`) plus one wiring block in `stacks/mantle/documents.tf`. Nothing in `stacks/core` changes; the `terraform.tfvars` symlinks and their contents are untouched (no new deployment variables are needed).
* One additive change to the shared `modules/auth/authentik/oidc_provider` (a `bind_app` switch plus two outputs) so this app can be bound to its own two groups without changing behaviour for the five existing callers (`immich`, `harbor/mantle`, `argo-cd`, `argo-workflows`, `grafana_oidc`).
* Library (`/documents`) on one RWX SeaweedFS claim `documents`; config + SQLite on longhorn `filebrowser-data` (Velero daily); thumbnails + search index on longhorn `filebrowser-cache` (excluded from backup).
* Ingress only from the private gateway data plane and from Prometheus; no ServiceMonitor, because FileBrowser Quantum emits no metrics yet. OnlyOffice, an LLM, and their own authentik applications are explicitly out of scope; the volume layout, the issuer/groups, and `http.internalUrl` are chosen so those arrive later without rework.
* No upstream Helm chart exists (the FBQ repo has no `charts/`/`deploy/` directory, and ArtifactHub only carries charts for the unrelated original FileBrowser), so this is a hand-rolled manifest module, exactly as the removed `modules/documents` (paperless-ngx, added in `f48a755`, removed in `8214af5`) did.

Upstream facts this plan relies on (verified against the FBQ repo and docs, 2026-09-30):

* Image `ghcr.io/gtsteffaniak/filebrowser:2.0.9-beta`. `.github/workflows/tag.yaml` strips the leading `v` from the release tag before pushing, so the pinned tag is `2.0.9-beta`; the moving `beta`, and the `2-beta`/`2.0-beta` aliases exist too, but this repo pins. `-slim` variants ship no ffmpeg and are not used.
* In the image it listens on `8080`; `GET /health` is the documented healthcheck and sits outside the default API log filter, so it is safe as a probe.
* Config resolution order: `-c <path>`, then `FILEBROWSER_CONFIG`, then `./config.yaml`, then `/home/filebrowser/data/config.yaml`. Secrets are documented as env vars layered over `config.yaml` (`FILEBROWSER_OIDC_CLIENT_ID`, `FILEBROWSER_OIDC_CLIENT_SECRET`, `FILEBROWSER_JWT_TOKEN_SECRET`).
* `server.database.path` defaults to `/home/filebrowser/data/filebrowser.sqlite` in the image; SQLite is the default engine (WAL, `busy_timeout` on every pooled connection).
* `server.cacheDir` holds thumbnails, archive scratch, and the SQLite search index (`cacheDir/sql`). Docs: index persistence across restarts *requires* a persistent, disk-backed cacheDir — never tmpfs, never a network path.
* v2.0.9 "startup now fails when the configured/env auth signing key differs from the key persisted in the application database", so the JWT signing key must be stable across restarts.
* OIDC keys are `auth.methods.oidc.{enabled,clientId,clientSecret,issuerUrl,scopes,userIdentifier,adminGroup,userGroups,groupsClaim,logoutRedirectUrl}`; the callback is `<baseURL>/api/auth/oidc/callback` and deliberately does *not* derive from `http.externalUrl`. Provider groups land write-through in the access-control GroupMap; `userGroups` denies login to anyone outside the list; with `password.enabled: false` and OIDC on, users are auto-redirected to the provider.
* `http.trustProxyHeaders: true` is required behind the gateway (FBQ logs a warning otherwise). `http.internalUrl` is the address integrations (later OnlyOffice) use to call back into FBQ.
* No Prometheus endpoint: the README's comparison table marks Metrics as in progress, the server-settings reference has no metrics key, and `backend/internal` has no metrics package.
* DNS and certificates need no work: `external-dns` (rfc2136 → `ns1.vn.linuxguru.net`, `gateway-httproute` source, `enableGatewayListenerSets = true`, `domainFilters = [vn.linuxguru.net]`) publishes the ListenerSet hostname, and cert-manager's gateway-shim issues `cert-<fqdn>` from the ListenerSet's `cert-manager.io/cluster-issuer` annotation.
[Types]
HCL has no type system beyond variable/output schemas; this is the equivalent specification.

`modules/documents/variables.tf` (name — type — default — purpose):

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `namespace` | string | `"documents"` | Namespace everything lives in. |
| `name` | string | `"filebrowser"` | Deployment, Service, ConfigMap, Secret, route name. |
| `domain` | string | required | Private domain; the default hostname derives from it. |
| `cert_issuer` | string | required | ClusterIssuer for the ListenerSet. |
| `hostname` | string | `null` | Full hostname; `locals.fqdn = coalesce(var.hostname, "docs.${var.domain}")`. |
| `gateway_name` | string | `"private"` | Shared gateway. |
| `gateway_namespace` | string | `"kube-network"` | |
| `monitoring_namespace` | string | `"monitoring"` | Prometheus namespace allowed on the app port. |
| `oidc_app_name` | string | `"documents"` | authentik application/provider name, issuer path segment, and prefix of the two groups. |
| `image` | string | `"ghcr.io/gtsteffaniak/filebrowser"` | |
| `image_tag` | string | `"2.0.9-beta"` | Pinned; bumping is a one-line change. |
| `port` | number | `8080` | Container and Service port. |
| `storage_class` | string | `"longhorn"` | Config/SQLite and cache claims. |
| `bulk_storage_class` | string | `"seaweedfs-csi"` | Library claim. |
| `data_size` | string | `"5Gi"` | Config + SQLite claim. |
| `cache_size` | string | `"20Gi"` | Thumbnails + search index claim. |
| `library_size` | string | `"1Pi"` | Library PVC request (repo convention). |
| `library_pv_size` | string | `"2Pi"` | Library PV capacity (repo convention). |
| `source_path` | string | `"/documents"` | Mount point and FBQ source root. |
| `source_name` | string | `"Documents"` | Display name in the UI. |
| `uid`, `gid` | number | `1000` | The image's built-in `filebrowser` user. |
| `icon` | string | `null` | authentik icon; null → dashboard-icons `filebrowser-quantum.svg`, `""` → none. |

`modules/documents/filebrowser/variables.tf`: `namespace`, `name`, `image`, `image_tag`, `port`, `hostname`, `data_pvc`, `cache_pvc`, `library_pvc`, `source_path`, `source_name`, `uid`, `gid`, `resources` (object with `requests`/`limits`), `oidc_issuer_url`, `oidc_admin_group`, `oidc_user_group`, `oidc_scopes`, `oidc_logout_url`, `client_id` (sensitive), `client_secret` (sensitive), `signing_key` (sensitive), `extra_config` (map(string)). The Deployment renders `userGroups` as `[var.oidc_admin_group, var.oidc_user_group]`, so both names must arrive even though only one of them grants admin.

`modules/auth/authentik/oidc_provider/variables.tf` addition: `bind_app` — bool, default `false`, "Bind the application to this module's own `<name>-admin` and `<name>-user` groups; off leaves the app unbounded unless `group_id` is set." Existing `group_id` semantics are unchanged.

`modules/auth/authentik/oidc_provider/outputs.tf` additions: `admin_group_id`, `user_group_id`, so a later sibling application (the LLM) can bind to these groups instead of minting `documents-llm-admin`/`-user` twins. `client_id`/`client_secret` unchanged.


[Files]
New files (all under `/Users/jblack/code/k8s/terraform`):

* `modules/documents/namespace.tf` — `kubernetes_namespace_v1.this` for `var.namespace`. Every other resource takes its namespace from `kubernetes_namespace_v1.this.metadata[0].name`, the way the removed paperless module did, so the module owns its own ordering.
* `modules/documents/variables.tf` — the inputs listed in [Types].
* `modules/documents/locals.tf` — `fqdn`, `icon`, `labels = { "app.kubernetes.io/name" = var.name }`, `admin_group = "${var.oidc_app_name}-admin"`, `user_group = "${var.oidc_app_name}-user"`, `data_pvc = "${var.name}-data"`, `cache_pvc = "${var.name}-cache"`, `library_pvc = "documents"`, and `issuer_url = "https://auth.${var.domain}/application/o/${var.oidc_app_name}/"`.
* `modules/documents/providers.tf` — `required_providers` for `kubernetes` and `kubectl` only (`authentik` and `tls` arrive through `module.auth`; the root stack already configures both).
* `modules/documents/volumes.tf` — the three claims:
  * `kubernetes_persistent_volume_claim_v1.documents` (name `documents`, RWX, `seaweedfs-csi`, request `var.library_size`, `selector.match_labels.seaweed_id = "documents"`, label `velero.io/exclude-from-backup = "true"`) and `kubernetes_persistent_volume_v1.documents` (capacity `var.library_pv_size`, `Retain`, CSI driver `seaweedfs-csi-driver`, volume handle `documents`, label `seaweed_id = "documents"`). Copy of `modules/media/photos.tf`.
  * `kubernetes_persistent_volume_claim_v1.data` — `filebrowser-data`, RWO, `var.storage_class`, `var.data_size`; the only backup target (see `backup.tf`).
  * `kubernetes_persistent_volume_claim_v1.cache` — `filebrowser-cache`, RWO, `var.storage_class`, `var.cache_size`, label `velero.io/exclude-from-backup = "true"`.
* `modules/documents/ingress.tf` — two `../network/firewalls/ingress` calls: `ingress` (whole namespace, `from_peers` = the gateway data plane `gateway.networking.k8s.io/gateway-name = var.gateway_name` in `var.gateway_namespace`, port `var.port`) and `ingress_metrics` (`pod_selector = local.labels`, `from_peers` = `monitoring` namespace pods `app.kubernetes.io/name = prometheus`, port `var.port`). `allow_nodes` keeps its default so kubelet probes still land.
* `modules/documents/egress.tf` — `egress_gateway` via `../network/firewalls/egress`: `to_peers` = the gateway data plane on 443, because OIDC discovery and token exchange go to `auth.<domain>`, which resolves to the gateway's LAN address and is therefore outside `allow_internet`. No `allow_internet` rule: `server.disableUpdateCheck: true` removes the only reason FBQ would reach the public internet.
* `modules/documents/listener.tf` — `module "expose"` from `../network/gateway/expose` with `name = var.name`, `hostname = local.fqdn`, `cert_issuer = var.cert_issuer`, the gateway inputs, `backend_name = var.name`, `backend_port = var.port`. Ungated: the route points straight at FBQ, which authenticates itself against authentik (the immich/paperless pattern), so `route_name` stays null.
* `modules/documents/auth.tf` — `module "auth"` from `../auth/authentik/oidc_provider`: `name = var.oidc_app_name`, `redirect_uri = "https://${local.fqdn}/api/auth/oidc/callback"`, `bind_app = true`, `meta_icon = local.icon`, `open_in_new_tab = true`.
* `modules/documents/backup.tf` — `module "backup"` from `../storage/backup/schedule`: `target = local.data_pvc`, `namespace`, `selector = local.labels`. Cron and TTL come from the module defaults (`0 3 * * *`, `168h`) — the same daily cadence as every other schedule in the cluster.
* `modules/documents/monitoring.tf` — `kubectl_manifest.alerts` holding a `PrometheusRule` in `var.namespace` labelled `release = prometheus` (Prometheus loads only rules carrying that selector) with `FilebrowserAppUnavailable` (`kube_deployment_status_replicas_available{namespace="documents"} < 1`, 15m, critical) and `FilebrowserAppRestarting` (`increase(kube_pod_container_status_restarts_total{namespace="documents"}[1h]) > 3`, 10m, warning). Deliberately **no ServiceMonitor**: FBQ has no `/metrics`; the rule in `ingress.tf` is the open metrics path, and adding the ServiceMonitor later is a four-line change since Prometheus already runs with `serviceMonitorSelectorNilUsesHelmValues = false`.
* `modules/documents/filebrowser/providers.tf` — `kubernetes` + `random`.
* `modules/documents/filebrowser/variables.tf` — the inputs listed in [Types].
* `modules/documents/filebrowser/locals.tf` — `labels = { "app.kubernetes.io/name" = var.name }`, `config_path = "/config/config.yaml"`.

* `modules/documents/filebrowser/config.tf` — `kubernetes_config_map_v1.config` (name `<name>-config`, YAML in [Functions]), `random_password.signing_key` (length 50, `override_special = "_-%@"`), and `kubernetes_secret_v1.config` (name `<name>-secret`) carrying `FILEBROWSER_OIDC_CLIENT_ID`, `FILEBROWSER_OIDC_CLIENT_SECRET`, `FILEBROWSER_JWT_TOKEN_SECRET`.
* `modules/documents/filebrowser/deployment.tf` — the Deployment (spec in [Functions]).
* `modules/documents/filebrowser/service.tf` — `kubernetes_service_v1.this`, ClusterIP, port `var.port` named `http`, selector `local.labels`.
* `stacks/mantle/documents.tf`:
  ```hcl
  module "documents" {
    source = "../../modules/documents"

    domain      = var.deployment.cluster.domains.private
    cert_issuer = var.deployment.cert_manager.external_issuer
    hostname    = "docs.${var.deployment.cluster.domains.private}"
  }
  ```
  Everything else stays at its default (namespace `documents`, tag `2.0.9-beta`, icon, group names). Only values a stack already owns are passed — the `modules/media/immich.tf` convention, not paperless's redundant `image_tag` pass-through.

Modified files:

* `modules/auth/authentik/oidc_provider/variables.tf` — add `bind_app` (bool, default false, description in [Types]).
* `modules/auth/authentik/oidc_provider/auth.tf` — append after `authentik_policy_binding.app`:
  ```hcl
  # Both own groups: admins have to be able to log in, and binding only -user would
  # force every admin into a second group purely to authenticate.
  resource "authentik_policy_binding" "own_groups" {
    for_each = var.bind_app ? {
      admin = authentik_group.admin.id
      user  = authentik_group.user.id
    } : {}

    target = authentik_application.app.uuid
    group  = each.value
    order  = 0
  }
  ```
* `modules/auth/authentik/oidc_provider/outputs.tf` — add `admin_group_id = authentik_group.admin.id` and `user_group_id = authentik_group.user.id`.

Deleted or moved files: none. The removed paperless module left no state, claims, authentik application, or DNS record behind (`grep -rn "paperless\|documents" --include='*.tf'` is empty), so nothing needs `moved`/`import`.


[Functions]
HCL's equivalents are locals, resources and module calls. Each is named here exactly as it must appear.

Locals:

* `modules/documents/locals.tf` — `fqdn = coalesce(var.hostname, "docs.${var.domain}")`; `icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"`; `icon = var.icon == null ? "${local.icon_cdn}/filebrowser-quantum.svg" : (var.icon == "" ? null : var.icon)` (the CDN path itself verified 200; `selfhst/icons` has no filebrowser icon); `labels = { "app.kubernetes.io/name" = var.name }`; `admin_group`/`user_group`; `data_pvc`/`cache_pvc`/`library_pvc`; `issuer_url`.
* `modules/documents/filebrowser/locals.tf` — `labels`; `config_path = "/config/config.yaml"`.

ConfigMap `<name>-config`, data key `config.yaml` (the crux of the app):

```yaml
http:
  port: 8080
  baseURL: "/"
  # OIDC derives the callback from the browser-facing URL, not from these.
  externalUrl: "https://docs.vn.linuxguru.net"
  # What the later OnlyOffice Document Server calls back into.
  internalUrl: "http://filebrowser.documents.svc.cluster.local:8080"
  trustProxyHeaders: true
server:
  database:
    path: /home/filebrowser/data/filebrowser.sqlite
  cacheDir: /home/filebrowser/cache
  disableUpdateCheck: true
  numImageProcessors: 2
  sources:
    - path: /documents
      name: Documents
      config:
        defaultEnabled: true
auth:
  methods:
    password:
      enabled: false
    oidc:
      enabled: true
      issuerUrl: "https://auth.vn.linuxguru.net/application/o/documents/"
      scopes: "openid email profile groups"
      userIdentifier: preferred_username
      adminGroup: documents-admin
      userGroups: ["documents-admin", "documents-user"]
      logoutRedirectUrl: "https://auth.vn.linuxguru.net/application/o/documents/end-session/"
```

Rationale for the non-obvious keys: `port: 8080` matches the image's own listen port; `internalUrl` is the integration callback address; `disableUpdateCheck` is what lets the namespace run with no internet egress; `numImageProcessors: 2` matches the CPU limit so ffmpeg previews cannot oversubscribe a small node; `defaultEnabled: true` is required or a freshly auto-created OIDC user logs in to an empty UI; `userGroups` lists both groups so a `documents-admin`-only member can still log in, with `adminGroup` promoting them. `clientId`/`clientSecret` are deliberately absent — they arrive as env vars from the Secret, which is the documented way to keep secrets out of the ConfigMap (and avoids feeding the module's sensitive outputs into a non-sensitive attribute, which HCL forbids). Values are templated from locals rather than hardcoded so `oidc_app_name`/`hostname` changes stay in one place.

Secret `<name>-secret` (env `envFrom`), all `stringData`:

| Key | Source |
|---|---|
| `FILEBROWSER_OIDC_CLIENT_ID` | `var.client_id` (`module.auth.client_id`) |
| `FILEBROWSER_OIDC_CLIENT_SECRET` | `var.client_secret` (`module.auth.client_secret`) |
| `FILEBROWSER_JWT_TOKEN_SECRET` | `random_password.signing_key.result` — must be stable, v2.0.9 refuses to start when the env key differs from the key already in the SQLite database |

One deliberate non-decision: FBQ's own automatic database backup (`FILEBROWSER_DISABLE_AUTOMATIC_BACKUP`) stays at its default, enabled. It writes inside the `data` claim, which Velero already protects, so it costs a little duplicate space in exchange for a fast recovery path after a bad migration; [Testing] item 1 checks how much it accumulates and it can be disabled with that one env var if it ever matters.

Deployment `kubernetes_deployment_v1.this`:

* `replicas = 1`; `strategy { type = "Recreate" }` — the data and cache claims are RWO longhorn volumes, so a surge replica would deadlock waiting for an attach that cannot happen until the old pod is gone.
* Pod template labels `local.labels`; annotations `checksum/config = sha256(jsonencode(kubernetes_config_map_v1.config.data))`, `checksum/secret = sha256(jsonencode(kubernetes_secret_v1.config.data))`, and `backup.velero.io/backup-volumes = "data"` (limits Velero's fs-backup to the config+SQLite volume, leaving the library and cache out even though they are mounted).
* `security_context { run_as_user = var.uid, run_as_group = var.gid, fs_group = var.gid }` — the image's built-in `filebrowser` user is 1000:1000, the same identity the media and immich pods use on SeaweedFS claims.
* `enable_service_links = false` — the Service is named `filebrowser`, and Kubernetes would otherwise inject `FILEBROWSER_PORT`/`FILEBROWSER_SERVICE_*` into a process whose entire configuration namespace is `FILEBROWSER_*`. Cheap insurance, and the same reasoning the paperless module recorded.
* One container `var.name`: image `${var.image}:${var.image_tag}`; `port { name = "http", container_port = var.port }`; `env_from secret_ref` plus `env { name = "FILEBROWSER_CONFIG", value = "/config/config.yaml" }`; `readiness_probe` and `liveness_probe` both `http_get { path = "/health", port = "http" }` with 10s/30s initial delays, 10s/30s periods, 5s timeout, thresholds 3/6; `resources` requests `cpu 100m`, `memory 512Mi`, limits `cpu 2`, `memory 2Gi` (docs put the floor at 512Mi and thumbnailing is the CPU-heavy part).
* Volumes: `data` → PVC `var.data_pvc` at `/home/filebrowser/data`; `cache` → PVC `var.cache_pvc` at `/home/filebrowser/cache`; `documents` → PVC `var.library_pvc` at `var.source_path`; `config` → ConfigMap `kubernetes_config_map_v1.config` at `/config` (default mode 0444). These volume names are what the Velero annotation above refers to.
* `service_account_name` left default, no RBAC required (FBQ talks to no API).

Service `kubernetes_service_v1.this`: ClusterIP, selector `local.labels`, one port `http` `var.port` → target port `http`. That is the `backend_name`/`backend_port` the ListenerSet route forwards to.


[Classes]
Terraform modules are the class equivalent.

* `module "documents"` (`modules/documents`, new) — owns the namespace, the three claims, the two firewalls, the ListenerSet/route, the authentik application, the Velero schedule and the namespace alerts. Public interface: the variables in [Types]; it exposes no outputs (nothing outside consumes it, and the LLM/OnlyOffice work later will call into the same module rather than read from it).
* `module "filebrowser"` (`modules/documents/filebrowser`, new) — the workload only: ConfigMap, Secret, Deployment, Service. Constructor inputs are the `*_pvc` names, the OIDC settings, the three secrets and resources. Nesting mirrors the removed `modules/documents/paperless/` and immich's `postgres/`, and leaves the sibling slots (`onlyoffice/`, later an LLM) empty next to it.
* `module "auth"` in `modules/auth/authentik/oidc_provider` (modified) — now also able to bind an application to its own two groups and to report their ids. Backward compatible: `bind_app` defaults to `false`, which reproduces today's behaviour byte for byte for `immich`, `harbor/mantle`, `argo-cd`, `argo-workflows` and `grafana_oidc`, and the new outputs are additive.
* Reused unchanged: `modules/network/firewalls/{ingress,egress}`, `modules/network/gateway/expose` (→ `listener_set` + `http_route`), `modules/storage/backup/schedule`.
* Not used, on purpose: `modules/auth/authentik/proxy_outpost`/`proxy_app` (no gatekeeper needed once FBQ authenticates natively) and `modules/media/media_app` (Helm-chart wrapper; there is no chart).

[Dependencies]
* Container image `ghcr.io/gtsteffaniak/filebrowser:2.0.9-beta`, pulled by kubelet from ghcr.io — the same registry the cluster already pulls `ghcr.io/m0nsterrr/*` and `ghcr.io/immich-app/*` from. No pull secret, no Harbor project entry. The full (non-`-slim`) image, so ffmpeg previews and PDF/video thumbnails work.
* No new Terraform providers and no version bumps: `kubernetes 3.0.1`, `kubectl 1.19.0`, `random 3.8.1`, `authentik 2026.8.0` and `tls 4.2.1` are already required and locked in `stacks/mantle/.terraform.lock.hcl`, and all five are configured in `stacks/mantle/providers.tf`.
* No Helm charts, no CRDs to apply (Velero, Gateway API, Prometheus Operator and cert-manager CRDs all already exist from `core`).
* External dependencies that must be true for this to work: authentik reachable at `auth.vn.linuxguru.net` (already true — `modules/network/whisker`, `seaweedfs_admin`, immich all rely on it), the `private` gateway in `kube-network` accepting ListenerSets from any namespace (true — `modules/network/gateways.tf` creates it with `routes_namespace = null`), and the `documents` group memberships being managed by hand in authentik after the first apply.
* No tfvars changes: no new key is read from `var.deployment`, so `~/.tfenvs/k8s.tfenv` and both `terraform.tfvars` symlinks stay untouched.


[Testing]
There is no test framework in this repository — no `*.tftest.hcl`, no Makefile, no CI workflow — so validation is `tofu` static checks, a reviewed plan, and a post-apply checklist. All commands run from `/Users/jblack/code/k8s/terraform/stacks/mantle` with OpenTofu 1.11.6 (`tofu`, `registry.opentofu.org` providers).

Pre-apply:

1. `tofu fmt -recursive ../../modules ../../stacks` — the repo keeps `terraform fmt`-clean files.
2. `tofu validate` — catches the usual HCL/type errors (sensitive values in non-sensitive attributes is the one to watch in `config.tf`).
3. `tofu plan -out=/tmp/documents.tfplan` and read it for three things:
   * only additions in `module.documents`, plus additions in `module.auth` (the new binding and outputs);
   * **no changes** to any existing authentik resource — grep the plan for `authentik_` and confirm every diff belongs to `documents`;
   * no churn on existing network policies (the firewall locals sort node and endpoint lists precisely to avoid that).
4. `tofu plan` again after applying the module fix alone if the first diff looks larger than expected — the auth change is the only edit to shared code, so isolating it is cheap.

Post-apply (in order, each one a real failure mode):

1. `kubectl -n documents get ns,pvc,pv` → `documents` PV `Available`/`Bound`, `filebrowser-data` and `filebrowser-cache` `Bound` on `longhorn`.
2. `kubectl -n documents get pod` → Running, 1/1, no restarts after two minutes; `kubectl -n documents logs deploy/filebrowser | head` shows no "signing key differs" error and no OIDC "trustProxyHeaders" warning.
3. `kubectl -n documents exec deploy/filebrowser -- curl -fsS -o /dev/null -w '%{http_code}' localhost:8080/health` → 200.
4. `kubectl get listenerset,httproute -n documents` → `Programmed`/`Accepted: True` on the `private` gateway; `kubectl get certificate -n documents` → `cert-docs.vn.linuxguru.net` `Ready`; the cert must contain the hostname, which is the signal that the ListenerSet annotation reached the gateway-shim.
5. `dig +short docs.vn.linuxguru.net @ns1.vn.linuxguru.net` → the private gateway's LB IP (external-dns published it from the HTTPRoute annotation; if it is missing, check that the `documents` namespace is not excluded by a `domainFilters` edge case in `modules/network/charts.tf`).
6. `curl -sSI https://docs.vn.linuxguru.net/health` from the LAN → 200 through the gateway, i.e. the route, cert and firewall all line up.
7. Browser: `https://docs.vn.linuxguru.net` redirects to authentik, a `documents-user` member lands in the UI, a `documents-admin` member sees the admin menu, and a user in neither group is denied. Confirm in authentik that the app's policy bindings cover both `documents-admin` and `documents-user`, and that the login created a user whose groups now appear under FBQ's group management.
8. Upload a file into `/documents`, confirm it appears on the SeaweedFS filer (`kubectl -n kube-storage exec deploy/seaweedfs-filer -- ...` or the admin UI) — this is the proof the RWX claim, not the container filesystem, holds the library. Delete it again.
9. `kubectl -n kube-backup get schedule filebrowser-data` and `velero backup get | grep filebrowser-data` after the first 03:00 run; a backup created on demand (`velero backup create --from-schedule`) is the faster check, and it should contain the `data` volume only.
10. `kubectl -n monitoring get prometheusrule -A | grep filebrowser` (rule loaded) and, once a synthetic failure is staged, confirm `FilebrowserAppUnavailable` can fire — a `kubectl -n documents scale deploy/filebrowser --replicas=0` for 16 minutes is the cheap rehearsal, then scale back.
11. Negative netpol checks: from another namespace pod, `curl filebrowser.documents.svc.cluster.local:8080/health` must time out (ingress is gateway-and-monitoring only); `kubectl -n documents exec deploy/filebrowser -- wget -qO- https://example.com` must fail (no internet egress), while the authentik redirect in the browser still works because that path leaves through the gateway rule.
12. Realtime/SSE smoke test: open a folder, upload from a second browser session, and confirm the first session updates without a reload. nginx-gateway-fabric is not configured for response buffering anywhere in this repo, so if this fails it is a gateway-policy question (a `ProxySettingsPolicy`/`ClientSettingsPolicy` knob), not an FBQ one — record the finding before changing anything.
13. Leave-print state clean: `git -P status --short` shows only the intended new/modified files, and `tofu plan` after apply is empty (no persistent diff on the claims, authentik binding, or the random secret).


[Implementation Order]
Each step leaves the tree in a state `tofu validate` accepts, and steps 1 and 2 are independent of everything after them.

1. **Shared auth module first, alone.** Edit `modules/auth/authentik/oidc_provider/{variables.tf,auth.tf,outputs.tf}` (`bind_app`, `own_groups` binding, two group-id outputs). Run `tofu validate` and `tofu plan` in `stacks/mantle` and confirm the plan is empty — that is the proof the change is inert for the five existing callers before anything depends on it.
2. **Module scaffold.** `modules/documents/{providers.tf,variables.tf,locals.tf,namespace.tf}` and `modules/documents/filebrowser/{providers.tf,variables.tf,locals.tf}` so the names, namespaces and claim names exist before resources reference them.
3. **Storage.** `modules/documents/volumes.tf` — the `documents` PVC+PV pair (RWX SeaweedFS, `Retain`, `seaweed_id` selector, backup-excluded) and the two longhorn RWO claims. Plan-check that both claims bind and that neither PVC shows a perpetual diff.
4. **Network + exposure.** `ingress.tf`, `egress.tf`, `listener.tf` (ListenerSet on `private`, route to the `filebrowser` Service on 8080, cert via `letsencrypt`, hostname `docs.<domain>`). Applying through this step proves the hostname/cert/DNS path before any app config exists.
5. **Identity.** `auth.tf` (authentik application `documents`, callback `https://docs.vn.linuxguru.net/api/auth/oidc/callback`, both own groups bound, `filebrowser-quantum.svg` icon) — then create the two memberships by hand in authentik (at least one person in `documents-user`, and in `documents-admin` for the admin) so step 8 can be tested.
6. **Workload.** `modules/documents/filebrowser/config.tf` (ConfigMap with the YAML above, `random_password.signing_key`, Secret), `deployment.tf`, `service.tf`. Watch the ordering here: the Secret consumes `module.auth`'s sensitive outputs, which is the only dependency between steps 5 and 6.
7. **Operations.** `backup.tf` (Velero schedule on `filebrowser-data`) and `monitoring.tf` (the two PrometheusRules). Neither is required for the app to serve, so they land last and can be split out if the apply needs to be staged.
8. **Stack wiring and first apply.** Add `stacks/mantle/documents.tf`, then `tofu fmt -recursive`, `tofu validate`, review `tofu plan`, apply, and walk the [Testing] checklist — stopping at the first failure rather than applying more.
9. **Deliberately deferred, with the seams already in place:** OnlyOffice (its own workload and `integrations.office.{url,internalUrl,secret}` in this ConfigMap; `http.internalUrl` already points at the Service so its callbacks work), the LLM search tool (its own authentik application via `module.auth`'s new group-id outputs, binding to `documents-user` rather than new twins, and a second reader of the same RWX `documents` claim), and a ServiceMonitor if and when upstream ships `/metrics`.


---

## Implementation notes (what actually happened)

Applied against the live cluster. Everything below is verified, not assumed.

Deviations from the plan above, all small and deliberate:

* `modules/documents/workload.tf` is a file the [Files] list omitted: it holds `random_password.signing_key` and the `module "filebrowser"` call that wires claims, OIDC settings and the three secrets into the submodule.
* `random_password.signing_key` lives in the parent, not in the submodule's `config.tf` as sketched. The parent has to pass the value in anyway, and a child module that both generates and receives it would produce an identity nobody reads.
* `cache_size` default is `25Gi`, not the planned `20Gi`. The app logs `cacheDir only has 19.50 GB of free space, this is less than the 20 GB minimum recommended free space` at exactly 20Gi, because that is its own floor. The claim was resized in place (longhorn online expansion; the pod needed one restart for the filesystem grow) and the warning is gone.
* `modules/documents/providers.tf` requires `random` as well as `kubernetes` and `kubectl`, for the signing key above.

Apply results:

* `tofu apply`: **29 added, 0 changed, 0 destroyed**. The shared `oidc_provider` change is provably inert — before this module was wired in, a plan with the module change alone showed no diff for `immich`, `harbor`, `argo-cd`, `argo-workflows` or `grafana_oidc`.
* `tofu fmt -recursive -check .` clean, `tofu validate` clean, and a plan after apply reports `No changes`.

Verified live:

* All three claims Bound; `persistentvolume/documents` 2Pi RWX `Retain` bound to `documents/documents`; `/documents` inside the pod is `seaweedfs-filer:8888:/buckets/documents`, and a file written there reads back through the filer's HTTP API (`/buckets/documents/healthcheck.txt` → the written contents). Test file removed afterwards.
* Pod Running, ready, 0 restarts. Logs show the SQLite database created, `Auth Methods: [oidc]`, `OIDC Auth configured successfully`, `Sources: [Documents: /documents]`, no signing-key error and no `trustProxyHeaders` warning.
* ListenerSet `Accepted`/`Programmed` True on the `private` gateway; `cert-docs.vn.linuxguru.net` `Ready` (issuer order `valid`); `docs.vn.linuxguru.net` → `192.168.0.100` from both `ns1.vn.linuxguru.net` and the LAN resolver used here; `https://docs.vn.linuxguru.net/health` → 200 through the gateway.
* authentik: application `documents` with the dashboard-icons `filebrowser-quantum.svg` icon, provider client_id `documents`, redirect URIs exactly `https://docs.vn.linuxguru.net/api/auth/oidc/callback`, and groups `documents-admin`/`documents-user` both policy-bound to the application.
* Network policy, from throwaway pods: inside `documents`, the authentik issuer is reachable (200) and `https://example.com` times out (no internet egress); from `default`, `filebrowser.documents:8080` times out (ingress is gateway and Prometheus only).
* Velero schedule `filebrowser-data` Enabled, cron `0 3 * * *`; `PrometheusRule filebrowser` present in `documents`.

Still outstanding, and by design not automatable:

1. **Group membership** — both groups have zero members. Add the human to `documents-user`, and to `documents-admin` for admin rights, in authentik.
2. **Browser checks** — OIDC login, launchpad tile, per-group access, the admin menu, and the SSE/realtime smoke test all need a person with a session. Note `GET /` returns 200 with the SPA shell and the redirect to authentik happens client-side, so a `curl` 302 is not the expected signal.
3. `PrometheusRule` firing and the first Velero backup are time-based; the alert-injection rehearsal in [Testing] item 10 has not been run.

## Follow-up: uploads did nothing (per-source permissions)

Symptom: a logged-in admin could browse but the upload action produced no request at all — nothing in nginx's access log and nothing in FBQ's API log.

Cause, read from the app's own SQLite database (`users.user_data`, copied out of the pod):

```json
"backendScopes": [{
  "path": "/documents", "scope": "/",
  "permissions": {"view": true, "download": true, "modify": false, "delete": false, "create": false, "configured": true}
}]
```

In v2, file permissions are **per source** (view/download/modify/create/delete) and `modify` is what gates upload/overwrite while `create` gates new files and folders. The app's built-in default for scopes issued to auto-provisioned users is view+download only — the `sourceAccessDefaults` row proves it:

```json
{"defaultPermissions":{"view":true,"download":true,"modify":false,"delete":false,"create":false,"configured":true},"enforcedPermissions":{}}
```

So every OIDC user starts read-only, the frontend renders no upload affordance, and no request is ever sent. Useful to know: the docs claim "Admins receive full file-operation access on every source automatically", but an admin whose scope carries explicit permissions still gets nothing — worth an upstream issue.

Two separate consequences, and only one of them is config:

1. **Existing users are not fixed by config.** `server.sources[].config.defaultPermissions` is a real key in 2.0.9-beta (verified: a deliberately bogus sibling key fails startup with a YAML error, this one does not), and it is now in the ConfigMap — but the database is authoritative once an instance has initialised, so restarting left both the `sourceAccessDefaults` row and jblack's scope unchanged. It seeds a fresh install, nothing more.
2. **The live fix is in the app's Access management / User management**, which is app state like authentik group membership — deliberately not terraform's:
   * User management → edit the user → expand the source row → enable **Modify** and **Create** (and **Delete** if wanted) → save, then reload the page.
   * Settings → **Access management → Permissions** → set the same defaults for future users; **Enforce** resyncs all *non-admin* users immediately, and admins are exempt.

Config change made anyway: the source now carries `defaultPermissions: {view, download, modify, create, delete: true}` so that a from-scratch install (or a disaster-rebuild that recreates the database) does not hand everyone a read-only library. If deletes should be off by default, that is one word in `modules/documents/filebrowser/locals.tf`.

### Resolution (applied to the live instance)

The defaults were fixed in the UI (**Access management → Permissions**, all five on — note this is what a UI save writes; it does not touch existing users). The existing user's scope was corrected directly in the app database, since neither the config key nor enforcement reaches an admin's own scope:

1. `kubectl -n documents scale deploy/filebrowser --replicas=0` — the app must be stopped; its database is in WAL mode, so a copy taken while it runs is stale by whatever sits in `filebrowser.sqlite-wal`.
2. Temporary `busybox` pod mounting the `filebrowser-data` claim. On clean exit the app had checkpointed the WAL away, leaving a single self-contained `filebrowser.sqlite`.
3. Copy out, `pragma integrity_check` → ok, then set `users.user_data → backendScopes[0].permissions.{modify,create,delete} = true` for `jblack`, `pragma wal_checkpoint(truncate)` and `pragma journal_mode=delete` so the artifact carries no sidecar dependency.
4. Copy back, `chown 1000:1000`, `chmod 664`, remove the temp pod, scale to 1. The app logged `Using existing database`, registered the source and served on 8080 with no errors; the signing key was preserved, so existing sessions survived. `tofu plan` afterwards: `No changes`, i.e. scaling by hand left no drift.

Verified working: `POST /api/resources?path=%2F20260930_001051.jpg&source=Documents` → **200** twice, an inline preview, and a `DELETE /api/resources/bulk` → 200. The library is empty again because that test file was removed.

Two lessons worth keeping: the app database is authoritative for permissions once an instance has booted, so these two records (`.settings['sourceAccessDefaults']` and each user's `backendScopes`) are the only places to look when someone cannot upload; and any future hand-edit of that database must be done with the app stopped for the WAL to be checkpointed.

### Correction: terraform asserts no permissions

The permissive `defaultPermissions` seed added to the source config was wrong — it would hand full rights to every user who can authenticate. It has been **removed**: the source carries only `defaultEnabled: true` and the app's own read-only default stands. Verified by restarting with the key removed and re-reading the database: the `sourceAccessDefaults` row was unchanged, which also proves the all-true defaults seen earlier came from a save in Access management, not from terraform. Permission governance for this app is app state, and belongs in Access management.

What this build can and cannot express, read from the database schema:

* `groups` is `(id, name, members)` — no permission columns. Groups (synced from the OIDC claim) can carry **access rules**, never file permissions.
* `access_rules` is `(id, source, path, rule_data)` and is currently empty. Rules scope *which paths* are reachable, per user, group, or everyone; the docs are explicit that an allow rule does not substitute for `create`/`modify`/`delete` on the user's scope.
* File permissions therefore exist in exactly two places: the **defaults** (every user who can authenticate) and each **user's scope** (per person). There is no "grant upload to `documents-user`" knob.

The authentik app binding still bounds who exists at all: only members of `documents-admin`/`documents-user` can authenticate, so defaults are "every member may…", not "the world may…".

### Final policy: closed by default, granted per user in the UI

Agreed shape, now live: **no access by default; read and write are granted per user in the app's UI.** It takes two settings, because they are two different mechanisms:

* **Source assignment** — `server.sources[].config.defaultEnabled = false` in this module, so a newly provisioned user gets no sources at all. Config-owned, because "which sources exist for whom by default" is part of the app's shape.
* **Permission baseline** — `settings.sourceAccessDefaults` in the app database, now `view/download/modify/create/delete = false` with no enforcement. This is the Access management page's data: it must stay all-false or it hands out rights to every user who can authenticate. IaC cannot own it (no provider, DB-only), and the module deliberately asserts no permissions.

The result, verified in the database after the last restart: defaults all false, exactly one user (`jblack`) and exactly one grant — his scope on `/documents` with view/download/modify/create/delete, which is what makes uploading work. Access rules: zero.

To give someone access, in the UI: **User management → edit the user → select the `Documents` source → set the scope path → tick View and Download for read, Modify and Create for write → Save** (Delete if they should be able to remove files). Access management then stays what its name says — a template for new scopes, not a grant.

Deliberately **not** enabled: `denyByDefault` on the source. It is the path-level counterpart (nothing reachable until an allow rule exists), but the docs give no indication that admins are exempt, so switching it on without first creating allow rules risks blacking out the library for everyone including the admin. If path-level closure per group is wanted later, the order is: create the allow rules (`filebrowser set rule -s Documents -p / -r group -v documents-user --allow`, or the UI), then set `denyByDefault: true`.

### Per-user folders (current policy)

Everyone the groups let in gets their own folder rather than a hand-assigned path:

```hcl
config = {
  defaultEnabled   = true
  createUserDir    = true
  defaultUserScope = "/users"
}
```

* `createUserDir: true` is what makes each user's root `<source>/users/<username>`. **Without it, `defaultUserScope` *is* the scope — every user shares `/users`**, which is what the first attempt produced. The docs' "createUserDir is deprecated, directories are always created" note is wrong for 2.0.9-beta; verified by probe (below).
* A newly provisioned user's scope then becomes `/users/<username>` — their root in the UI — and the directory is created. Whether the *scope value* follows (and therefore whether siblings are unreachable, which is what makes the directory private) is confirmed at the next provisioning; it could not be read out of the probe database because the app leaves the WAL un-checkpointed until clean shutdown, so a copy is not replayable.
* The Access management baseline is all five flags **true**: `view`, `download`, `modify`, `create`, `delete`. Because each user's scope is confined to their own folder, that baseline grants read/write/delete *inside that folder*, not across the library. It seeds any new scope, so an admin adding a shared scope later should set that scope's permissions explicitly rather than relying on the baseline.
* `jblack` is untouched: scope `/` (the shared root) with full rights, which is the admin's grant.
* Confinement is the reason this is not the "globally accessible" shape the earlier attempt was: the baseline can only apply within the one folder each user is scoped to.

Verification status, stated honestly:

* Observed: the app creates the `defaultUserScope` directory (`.../users`) when a user is provisioned — reproduced in an isolated throwaway instance inside the pod with its own database and source directory. It is *not* created at server startup on the live instance, so directory creation is tied to provisioning, not boot.
* Observed, and this is the fix for the shared-`/users` problem: with `createUserDir: true` the same isolated probe produced `.../users/alpha` for user `alpha`, while without it only `.../users` existed. Same user-creation path, one key apart — that is the difference between a private directory per user and a shared one.
* Observed: a real OIDC-provisioned user (`testblack`, created before this change) came out with scope `/` and all permissions false, i.e. the pre-change defaults — which is exactly the behavior this change replaces.
* Not yet observed end-to-end: a provisioning *after* the change. `testblack` is the ready-made test: deleting that user in User management and letting them log in once more should re-provision them at `/users/testblack` with the new baseline. Support for the mechanism is the docs plus the `DefaultUserScope` field on the source struct in `internal/database/users/users.go`, but until a login happens it is unproven.
* Still open, deliberately: how a user also gets access to the *shared* tree (needed for OnlyOffice collaboration later). The candidates are a second scope row for the same source or `denyByDefault` + per-group rules; I will verify which this build supports before wiring it.






## Follow-up: flat read-only root, personal space, share links (applied)

Final shape, after sharing was briefly turned off and then turned back on by request:

* **Flat root** — the `Shared` source (`/documents/shared`), scope `/` for every user, and
  **read-only**: `readOnly: true`, the source-level switch this build describes as "changes from the
  UI, webdav, and API will be disabled". It binds admins too, which is the point — a permission flag
  could not, because `AdminPerms()` hardcodes full file rights.
* **Personal space** — the `Documents` source (`/documents`) with `createUserDir` and
  `defaultUserScope: /users`, so each user's scope is `/users/<username>`: writable, and *not*
  `private`, because a link out of it is the only self-service way to hand a file to someone else.
* **Sharing** — `userDefaults.account.permissions.share = true`. Links can only originate in the
  personal source, the flat root being `private` ("no sharing permitted").

Why two sources instead of rules on one: write permission lives on the **scope row**, and access
rules only gate which paths are reachable ("an allow rule does not substitute for create, modify or
delete"). One source therefore cannot be read-only at its root and writable under `/users`; since
`readOnly` is per source, the split is the only expressible shape. Unchanged: one scope per source
per user (`BackendScope` keyed by `Path`, `GetScopeForSourcePath` returns the first match).

### Trap found: `defaultPermissions` is not per-source in this build

The first attempt also gave the `Shared` source a read-only `defaultPermissions`. On startup those
values were written into the **global** `settings.sourceAccessDefaults` row — the generated config
says as much: `defaultPermissions ... (also synced globally via Access settings)` — flipping the
instance's baseline from all-true to view/download-only, which would have handed every newly
provisioned user a **read-only personal space**. Reverted: the module asserts no scope-row
permissions at all, and the flat root rests on `readOnly` alone.

The baseline was restored by declaring the all-true template for one apply (a source config is the
only way to write that row) and then removing the declaration; the row persists, because nothing
re-syncs built-in defaults while no source declares any. Relevant to a rebuild: a fresh install
seeds the built-in read-only defaults, so new users would arrive unable to write in their own space
until Access management is saved, or `defaultPermissions` is declared for one apply.

Verified:

* rendered config: `Documents` `{defaultEnabled, createUserDir, defaultUserScope: /users}`,
  `Shared` `{defaultEnabled, private, readOnly}`, `userDefaults.account.permissions.share: true`.
* database: `settings.sourceAccessDefaults` all five true (its pre-existing value),
  `settings.userDefaults.default` `share: true`, and every user still holding
  `{/documents: / or /users/<name>, /documents/shared: /}`.
* logs: `Sources: [Documents: /documents Shared: /documents/shared]`, both indexes initialising, no
  errors or warnings. `tofu fmt -recursive -check` and `validate` clean; `tofu plan` reports no
  changes.

### End-to-end check, driven over the API against a throwaway instance

Method: a second FileBrowser process inside the pod (same image, own config on port 8099, a
*copy* of the live database, password auth on) so nothing about the live app's auth posture changed;
the two live users were given the test password on the copy only. Requests were `wget` with
`Authorization: Bearer <jwt>`.

Login contract, for the record — a JSON body gets 401:

* `POST /api/auth/login?username=<u>&recaptcha=` with the password in an **`X-Password`** header.
* The response is the raw JWT, also set as `Set-Cookie: filebrowser_quantum_jwt=…`; either
  `Authorization: Bearer` or that cookie works afterwards.

Results:

* **Personal space is writable**: `POST /api/resources?path=/sharetest.txt&source=Documents` as
  `testblack` → **200** (file present on the claim with uid 1000).
* **Flat root is read-only for a non-admin**: the same POST with `source=Shared` → **403 Forbidden**.
  (`readOnly` is source-level; whether it also binds the admin was not isolated, since the admin's
  earlier delete went through the *writable* `Documents` source.)
* **Sharing out of a personal space works, and the restriction is enforced**: a share created on
  `/users/testblack/20260929_125824.jpg` with `allowedUsernames: ["testblack2"]` and
  `disableAnonymous: true` gave, against `GET /public/api/resources?hash=<hash>`:
  **200** for `testblack2` (whose own scope in that source is only `/users/testblack2`), then
  **200 / 900792 bytes** on `…/public/api/resources/download?hash=<hash>`; **403** anonymous;
  **403** for a user not in `allowedUsernames`. So a recipient never needs a scope on the shared
  path — the source in their scopes is enough, and only listed users get in.

Three things the probe turned up that are worth knowing before the next share work:

1. `POST /api/share` takes the path **relative to the caller's scope**: passing
   `/users/testblack/file.jpg` stores `/users/testblack/users/testblack/file.jpg` and serves 404
   forever. The UI is correct (`path: "/20260929_125824.jpg"` from a user scoped at
   `/users/testblack` stores `/users/testblack/20260929_125824.jpg`).
2. Two logins in the **same second** produce an identical JWT (minimal claims; identity comes from
   the `hashed_tokens` row), so the second registration wins and the first session is attributed to
   the wrong user. Space logins out when scripting, and treat odd `username` columns in the access
   log with suspicion.
3. Shares are owned by `user_id`, so deleting and re-provisioning a user **orphans their shares**:
   the live instance still holds `YpkkvlVlwV7_ilPdKhiDjA` from the pre-delete `testblack`, listed
   for nobody (`/api/share/list` → `[]`) and pointing at `/users/testblack/ljljj`, which the same
   session's bulk delete removed.

Also seen in the live log while testing: the earlier `DELETE /api/resources/bulk` took
`/documents/shared` (the flat root) and `/documents/testme` with it, because the flat root is a
subdirectory of the *writable* `Documents` source and that call came in through “Documents”. The
directory was recreated empty. If the shared tree must not be deletable at all, its path has to move
out of the personal source's tree (own claim/bucket), or the admin's `Documents` scope has to stop
covering `/`.



