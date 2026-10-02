# Implementation Plan

## [Overview]

Stand up **ownCloud Infinite Scale (oCIS)** as a self-hosted "Google Drive" in a new `documents` namespace, exposed at `drive.vn.linuxguru.net` on the shared private gateway, with authentik as the sole identity source, SeaweedFS S3 as the blob store, and longhorn for metadata.

Scope and context:

- This follows the repo's structure: reusable `modules/<domain>/…` composed by `stacks/{core,mantle}`. Per `.clinerules/main.md` the work lands in **`stacks/mantle`** (app-style modules: media, blender, vaultwarden live there); `stacks/apps`/ArgoCD are out of scope. Comments stay terse (why, not what); `git -P` and `mpssh` are the available tools.
- The parent module is **`terraform/modules/documents`** (creates the namespace + baseline firewalls); it calls the app submodule **`terraform/modules/documents/owncloud`**.
- Three new reusable modules are introduced: `modules/auth/authentik/ldap_outpost`, `modules/storage/seaweedfs/bucket`, `modules/storage/seaweedfs/s3_user`.
- Identity: authentik **external user management** for oCIS (OIDC for auth + an authentik **LDAP outpost** for the user/group directory). oCIS's built-in `idp` and `idm` are disabled; there is **no `idm` volume**.
- Storage: oCIS `storage-users` uses the **`s3ng`** driver — blobs go to the SeaweedFS bucket `owncloud-storage`, decomposedfs metadata stays on the longhorn PVC `owncloud-metadata`. No CSI mount into oCIS (blobs go over the S3 API).
- Exposure via the shared `kube-network/private` gateway (same pattern as `vaultwarden`/`seaweedfs_admin`), not a per-namespace gateway.
- No OCM, internet egress disabled, ollama/`ai` access deferred.

Key facts verified during investigation (drive the design):

- SeaweedFS S3 endpoint `https://s3.vn.linuxguru.net` (region `seaweedfs`); buckets/identities provisioned in-cluster with `weed shell` (`s3.bucket.create`, `s3.configure … -apply`, `s3.accesskey.create`), which are **idempotent** (bucket = filer upsert; `s3.configure` = get-or-create + `addUniqueToSlice` + credential upsert; `s3.accesskey.create` rejects collisions and must be guarded).
- The oCIS chart injects S3 creds from a Secret with keys **`accessKey`/`secretKey`**, referenced by `secretRefs.s3CredentialsSecretRef`.
- oCIS chart persistence is **disabled by default** per service; the oCIS `storageusers`/`storagesystem` volumes are **xattr-heavy** (decomposedfs) → longhorn (ext4) is correct. Other services are plain state.
- The chart's `features.externalUserManagement` disables `idm`+`idp` but **requires an external LDAP** (not OIDC alone).
- authentik's LDAP outpost is **read-only** → `autoprovisionAccounts` must stay off.

## [Types]

Terraform has no user-defined classes/enums; the type surface is **module variable schemas** and **local object shapes**. All new variables are typed; secrets are `sensitive = true`.

### `modules/documents/variables.tf`
- `namespace { default = "documents" }`
- `domain { type = string }` — private domain (`vn.linuxguru.net`).
- `cert_issuer { type = string }` — `letsencrypt`.
- `gateway_name { default = "private" }`
- `gateway_namespace { default = "kube-network" }`
- `auth_namespace { default = "kube-auth" }`
- `monitoring_namespace { default = "monitoring" }`
- `hostname { default = "drive" }` — becomes `drive.<domain>`.

### `modules/documents/owncloud/variables.tf`
- `namespace { default = "documents" }`
- `name { default = "owncloud" }`
- `domain { type = string }`
- `hostname { default = "drive" }`
- `cert_issuer { type = string }`
- `gateway_name { default = "private" }`, `gateway_namespace { default = "kube-network" }`
- `auth_namespace { default = "kube-auth" }`, `monitoring_namespace { default = "monitoring" }`
- `helm_version { default = "0.8.0" }` — pinned `owncloud/ocis` chart.
- `image_tag { default = "8.2.0" }` — pinned image.
- `storage_class { default = "longhorn" }`
- `metadata_size { default = "5Gi" }`, `storagesystem_size { default = "1Gi" }`, `nats_size { default = "1Gi" }`
- `proxy_service_name { default = "owncloud-proxy" }` — HTTPRoute backend (confirm via `helm template`).
- `s3_endpoint { default = "https://s3.vn.linuxguru.net" }`, `s3_region { default = "seaweedfs" }`, `s3_bucket { default = "owncloud-storage" }`
- `ldap_uri { type = string }`, `ldap_bind_dn { type = string }`, `ldap_user_base_dn { type = string }`, `ldap_group_base_dn { type = string }`
- `oidc_client_id { type = string }`, `oidc_issuer_url { type = string }`
- `metrics_enabled { default = true }`, `icon { default = null }`

### `modules/storage/seaweedfs/bucket/variables.tf`
- `bucket { type = string }`, `owner { default = "" }`
- `seaweedfs_namespace { default = "kube-storage" }`, `seaweedfs_release { default = "seaweedfs-s3" }`, `seaweedfs_container { default = "seaweedfs" }`, `seaweedfs_master { default = "seaweedfs-master:9333" }`

### `modules/storage/seaweedfs/s3_user/variables.tf`
- `user`, `bucket { type = string }`, `actions { default = "Admin" }`
- `namespace { type = string }`, `secret_name { default = null }`
- `access_key_key { default = "accessKey" }`, `secret_key_key { default = "secretKey" }` (must match the oCIS chart's expected secret keys)
- `access_key_length { default = 20 }`, `secret_key_length { default = 40 }`
- `seaweedfs_*` (same four as `bucket`)

### `modules/auth/authentik/ldap_outpost/variables.tf`
- `namespace { default = "kube-auth" }`, `outpost_name { default = "ldap" }`, `service_name { default = "authentik-ldap" }`
- `group_name { default = "platform" }`, `base_dn { default = "dc=ldap,dc=goauthentik,dc=io" }`
- `bind_mode { default = "direct" }`, `search_mode { default = "cached" }`
- `domain { type = string }`, `core_namespace { default = "kube-auth" }`
- `image { default = "ghcr.io/goauthentik/ldap" }`, `image_tag { default = "2026.8.0" }`, `ldaps_port { default = 636 }`

### Locals shapes
- `local.fqdn = "${var.hostname}.${var.domain}"`.
- `local.helm_values` — the oCIS chart values object (see [Classes] → owncloud).
- `local.backup_targets` — map of Velero target name → pod selector.
- `local.labels = { "app.kubernetes.io/name" = var.name }`.

## [Files]

### New — `terraform/modules/documents/`
- `namespace.tf` — `kubernetes_namespace_v1.namespace` (`var.namespace`).
- `ingress.tf` — `module.ingress_baseline` (`network/firewalls/policy`, direction=ingress, name=`documents-ingress`); admits the namespace's own pods + node IPs.
- `egress.tf` — `module.egress_baseline` (direction=egress, name=`documents-baseline-egress`, `allow_internet=false`); DNS + self.
- `owncloud.tf` — `module.owncloud { source = "./owncloud" … }` passing domain/cert_issuer/gateway/auth/monitoring/sizes/ldap/oidc.
- `variables.tf`, `providers.tf` (`required_providers`: kubernetes, helm, kubectl, authentik), `outputs.tf` (fqdn, s3 secret name — optional).

### New — `terraform/modules/documents/owncloud/`
- `providers.tf` — `required_providers`: kubernetes, helm, kubectl, authentik, random.
- `locals.tf` — `fqdn`, `labels`, `helm_values` (oCIS chart values object), `backup_targets`.
- `helm.tf` — `helm_release.ocis` (chart `ocis`, repo `https://owncloud.github.io/ocis-charts/`, version `var.helm_version`, namespace, `values = [yamlencode(local.helm_values)]`, `wait`, `timeout = 900`).
- `auth.tf` — `module.oidc` (`auth/authentik/oidc_provider`, `name="owncloud"`, `redirect_uri="https://${local.fqdn}/"`, `extra_redirect_uris=[…/oidc-callback.html, …/oidc-silent-redirect.html]`, `bind_app=true`) → `owncloud-admin`/`owncloud-user` groups + provider; outputs feed `local.helm_values` and `var.oidc_client_id`.
- `listener.tf` — `module.expose` (`network/gateway/expose`, `name="owncloud"`, `hostname=local.fqdn`, `backend_name=var.proxy_service_name`, `backend_port=9200`).
- `storage.tf` — three `kubernetes_persistent_volume_claim_v1` (`owncloud-metadata` RWO, `owncloud-storagesystem` RWO, `owncloud-nats` RWO, all `var.storage_class`, sizes from vars); `module.bucket`; `module.s3_user`.
- `ingress.tf` — `module.ingress_gateway` (admit `kube-network/private` → proxy `:9200`); `module.ingress_metrics` (admit `monitoring/prometheus` → oCIS metrics ports; count on `var.metrics_enabled`).
- `egress.tf` — `module.egress_gateway` (peer `kube-network/private` `:443`, for OIDC issuer + S3 endpoint); `module.egress_ldap` (peer `kube-auth` → LDAPS `636`).
- `backup.tf` — `module.backup { for_each = local.backup_targets }` (`storage/backup/schedule`).
- `monitoring.tf` — optional ServiceMonitor + Grafana dashboard ConfigMap (`grafana_dashboard=1`).
- `variables.tf`, `outputs.tf`.

### New — `terraform/modules/storage/seaweedfs/bucket/`
- `main.tf` — `terraform_data.bucket` with `triggers_replace = { bucket, owner, script = filesha256("${path.module}/provision.sh") }` and a `local-exec` running `sh ${path.module}/provision.sh`.
- `provision.sh` — idempotent `weed shell` driver (see [Functions]).
- `variables.tf`, `outputs.tf` (`bucket`), `providers.tf` (none needed — no provider resources; declare `terraform {}` with no required_providers or omit).

### New — `terraform/modules/storage/seaweedfs/s3_user/`
- `main.tf` — `random_password.access_key`/`secret_key`; `terraform_data.user` (local-exec `provision.sh`); `kubernetes_secret_v1.credentials` with `{ (var.access_key_key) = …, (var.secret_key_key) = … }`.
- `provision.sh` — idempotent `s3.configure … -apply` driver.
- `variables.tf`, `outputs.tf` (`secret_name`, `access_key_id`), `providers.tf` (`random`, `kubernetes`).

### New — `terraform/modules/auth/authentik/ldap_outpost/`
- `main.tf` — `authentik_provider_ldap`, `authentik_application`, `authentik_outpost` (type `ldap`), an access `authentik_group`, an `authentik_rbac_role` + `authentik_rbac_permission_role` (object perm on the provider = "Search full LDAP directory"), the bind user + its password, the outpost `authentik_token`, a `kubernetes_secret_v1` (outpost API) and a `kubernetes_secret_v1` for the bind password (key `reva-ldap-bind-password`), and the `kubernetes_deployment_v1`+`kubernetes_service_v1` for the LDAP outpost (mirror `proxy_outpost`).
- `variables.tf`, `outputs.tf` (`service_name`, `bind_dn`, `base_dn`, `bind_password_secret`), `providers.tf` (`authentik`, `kubernetes`).

### New — `terraform/stacks/mantle/documents.tf`
- `module.documents { source = "../../modules/documents"; domain = var.deployment.cluster.domains.private; cert_issuer = var.deployment.cert_manager.external_issuer; … }`.

### Modified
- `terraform/stacks/mantle/` — add `documents.tf`; **no change** to `providers.tf` (kubernetes/helm/kubectl/authentik/random are already configured) or `variables.tf`.
- **No tfvars change**: `weed shell` provisioning needs no SeaweedFS admin key, so nothing new lands in `terraform.tfvars`.

### Deleted / moved
- None.

## [Functions]

Terraform has no user functions here; this section covers the **local-exec scripts** and the **Terraform locals** that encapsulate reusable logic.

### `modules/storage/seaweedfs/bucket/provision.sh`
```sh
#!/bin/sh
# Converges one SeaweedFS bucket; create is an upsert, so re-runs are no-ops.
set -eu

ws() {
  printf '%s\n' "$1" | kubectl -n "$SEAWEEDFS_NAMESPACE" exec -i "deploy/$SEAWEEDFS_RELEASE" \
    -c "$SEAWEEDFS_CONTAINER" -- weed shell -master="$SEAWEEDFS_MASTER"
}

if [ -n "$OWNER" ]; then
  ws "s3.bucket.create -name $BUCKET -owner $OWNER"
else
  ws "s3.bucket.create -name $BUCKET"
fi
```
Driven by `terraform_data.bucket` (`triggers_replace = { bucket, owner, script = filesha256(...) }`); env: `SEAWEEDFS_NAMESPACE/RELEASE/CONTAINER/MASTER`, `BUCKET`, `OWNER`.

### `modules/storage/seaweedfs/s3_user/provision.sh`
```sh
#!/bin/sh
# Converges one S3 user + bucket-scoped action + credential; s3.configure upserts, so re-runs are no-ops.
set -eu

ws() {
  printf '%s\n' "$1" | kubectl -n "$SEAWEEDFS_NAMESPACE" exec -i "deploy/$SEAWEEDFS_RELEASE" \
    -c "$SEAWEEDFS_CONTAINER" -- weed shell -master="$SEAWEEDFS_MASTER"
}

ws "s3.configure -user=$USER -actions=$ACTIONS -buckets=$BUCKET -access_key=$ACCESS_KEY -secret_key=$SECRET_KEY -apply"
```
Idempotency: `s3.configure -apply` does get-or-create + `addUniqueToSlice` (actions) + credential upsert (updates the secret if the key exists, else appends), so re-running with the same `random_password` values is a no-op; changing them rotates in place. Env: `SEAWEEDFS_*`, `USER`, `ACTIONS`, `BUCKET`, `ACCESS_KEY`, `SECRET_KEY`.

### Terraform locals
- `local.fqdn = "${var.hostname}.${var.domain}"`.
- `local.helm_values` — the oCIS chart values object (see [Classes] → `documents/owncloud`), built from module inputs + `module.oidc` outputs + `module.s3_user` outputs.
- `local.backup_targets` — map of Velero target → pod selector, e.g. `owncloud-metadata → { "app.kubernetes.io/name" = "storageusers", "app.kubernetes.io/instance" = "owncloud" }` (selectors confirmed via `helm template`).

## [Classes]

Terraform's analog to classes is the **module**. Each new module is described with its resources, inputs, and outputs.

### Module `documents` (parent) — `modules/documents/`
- **Purpose**: owns the namespace + baseline firewalls; composes the app.
- **Inputs**: `namespace`, `domain`, `cert_issuer`, `gateway_name`, `gateway_namespace`, `auth_namespace`, `monitoring_namespace`, `hostname`.
- **Resources**: `kubernetes_namespace_v1.namespace`; `module.ingress_baseline` + `module.egress_baseline` (`network/firewalls/policy`).
- **Sub-call**: `module.owncloud` (`./owncloud`).
- **Outputs**: `fqdn`, `s3_secret_name` (optional passthroughs).

### Module `owncloud` — `modules/documents/owncloud/`
- **Purpose**: the oCIS app — Helm release, OIDC client, exposure, storage, firewalls, backups.
- **Inputs**: as listed in [Types].
- **Resources / submodules**:
  - `helm_release.ocis` — chart `ocis`, `https://owncloud.github.io/ocis-charts/`, `0.8.0`, `depends_on = [module.bucket, module.s3_user, module.oidc, kubernetes_persistent_volume_claim_v1.*]`.
  - `module.oidc` — `auth/authentik/oidc_provider` (`name="owncloud"`, `bind_app=true`).
  - `module.expose` — `network/gateway/expose` (hostname `drive.<domain>`, backend `<proxy_service_name>:9200`).
  - `kubernetes_persistent_volume_claim_v1.metadata` (`owncloud-metadata`, `var.metadata_size`), `.storagesystem` (`owncloud-storagesystem`), `.nats` (`owncloud-nats`) — longhorn, RWO.
  - `module.bucket` — `storage/seaweedfs/bucket` (`owncloud-storage`, `owner="owncloud"`).
  - `module.s3_user` — `storage/seaweedfs/s3_user` (`owncloud`, bucket, `actions="Admin"`, keys `accessKey`/`secretKey`, namespace `documents`).
  - `module.ingress_gateway` (peer `kube-network/private` → `:9200`), `module.ingress_metrics` (peer `monitoring/prometheus`, `count = var.metrics_enabled`), `module.egress_gateway` (peer `kube-network/private` `:443`), `module.egress_ldap` (peer `kube-auth` → `636`).
  - `module.backup` (`for_each = local.backup_targets`) — `storage/backup/schedule`.
- **Outputs**: `fqdn`, `s3_secret_name`, `client_id` (optional).

- **`local.helm_values` (key set; everything else stays at chart defaults)**, verified against `owncloud/ocis` `0.8.0`:
  - `image.tag = var.image_tag` (`8.2.0`); `externalDomain = local.fqdn`.
  - `replicas = 1`; `deploymentStrategy.rollingUpdate = { maxSurge = 0, maxUnavailable = 1 }` (RWO-safe rollout).
  - `ingress.enabled = false` (Gateway API listener instead).
  - `features.ocm.enabled = false`.
  - `features.externalUserManagement.enabled = true`:
    - `autoprovisionAccounts.enabled = false` (authentik LDAP is read-only).
    - `oidc.issuerURI = var.oidc_issuer_url`; `oidc.userIDClaim = "preferred_username"`; `oidc.userIDClaimAttributeMapping = "username"`; `oidc.accessTokenVerifyMethod = "jwt"`; `oidc.roleAssignment.enabled = true`, `claim = "groups"`, mapping `owncloud-admin → admin`, `owncloud-user → user`.
    - `ldap.uri = var.ldap_uri`; `ldap.bindDN = var.ldap_bind_dn`; `ldap.certTrusted = true`; `ldap.user.baseDN = var.ldap_user_base_dn`; `ldap.group.baseDN = var.ldap_group_base_dn`.
  - `services.storageusers.storageBackend.driver = "s3ng"`; `driverConfig.s3ng.endpoint/region/bucket = var.s3_endpoint/s3_region/s3_bucket`.
  - `services.storageusers.persistence = { enabled = true, existingClaim = "owncloud-metadata", accessModes = ["ReadWriteOnce"] }`.
  - `services.storagesystem.persistence = { enabled = true, existingClaim = "owncloud-storagesystem", accessModes = ["ReadWriteOnce"] }`.
  - `services.nats.persistence = { enabled = true, existingClaim = "owncloud-nats", accessModes = ["ReadWriteOnce"] }`.
  - `services.{search,authapp,thumbnails,web}.persistence.enabled = false` (emptyDir).
  - `services.web.oidc.webClientID = var.oidc_client_id`.
  - `secretRefs.s3CredentialsSecretRef = module.s3_user.secret_name`.
  - `secretRefs.ldapSecretRef = <module.ldap_outpost bind-password secret>` (key `reva-ldap-bind-password`).

### Module `bucket` — `modules/storage/seaweedfs/bucket/`
- **Purpose**: idempotently create one SeaweedFS S3 bucket.
- **Inputs**: `bucket`, `owner`, `seaweedfs_*`.
- **Resources**: `terraform_data.bucket` (`local-exec` → `provision.sh`).
- **Outputs**: `bucket`.

### Module `s3_user` — `modules/storage/seaweedfs/s3_user/`
- **Purpose**: idempotently create one S3 user + bucket-scoped action + credential, and publish the credential as a Secret.
- **Inputs**: `user`, `bucket`, `actions`, `namespace`, `secret_name`, key names/lengths, `seaweedfs_*`.
- **Resources**: `random_password.access_key`/`secret_key`; `terraform_data.user` (`local-exec` → `provision.sh`); `kubernetes_secret_v1.credentials` (`{ (access_key_key) = …, (secret_key_key) = … }`).
- **Outputs**: `secret_name`, `access_key_id`.

### Module `ldap_outpost` — `modules/auth/authentik/ldap_outpost/`
- **Purpose**: expose authentik's read-only LDAP directory to oCIS (external user management).
- **Inputs**: as listed in [Types]; shape mirrors `modules/auth/authentik/proxy_outpost`.
- **Resources**:
  - `authentik_provider_ldap` (`name`, `base_dn`, `bind_flow`, `unbind_flow`, `bind_mode`, `search_mode`).
  - `authentik_application` (LDAP app).
  - `authentik_group.access` (who may bind/search).
  - `authentik_rbac_role` + `authentik_rbac_permission_role` — object permission on the LDAP provider ("Search full LDAP directory").
  - Bind user (username/password) + role/group membership.
  - `authentik_outpost` (`type = "ldap"`, `protocol_providers = [provider.id]`); `authentik_token` for the outpost SA.
  - `kubernetes_secret_v1` (outpost API: `AUTHENTIK_HOST`/`AUTHENTIK_HOST_BROWSER`/`AUTHENTIK_TOKEN`) and `kubernetes_secret_v1` (bind password, key `reva-ldap-bind-password`).
  - `kubernetes_deployment_v1` + `kubernetes_service_v1` running `ghcr.io/goauthentik/ldap` in `var.namespace` (mirror `proxy_outpost`'s deployment/secret pattern).
- **Outputs**: `service_name`, `bind_dn`, `base_dn`, `bind_password_secret`.
- **Caveat**: the `authentik_rbac_permission_role` **codename** and the role→user linkage are the least-certain pieces; confirm against the live authentik API at implementation time, and if the provider has no handle for the user↔role link, document a one-time UI step in the module header.

## [Dependencies]

- **New Helm chart**: `owncloud/ocis` from repo `https://owncloud.github.io/ocis-charts/`, pinned to **`0.8.0`** (appVersion `8.2.0`); image `owncloud/ocis:8.2.0` (pulled via the cluster's Docker Hub pull-through cache). Upstream labels the chart "experimental" — the pin isolates us.
- **Existing in-repo modules reused (no change)**: `network/gateway/expose`, `network/firewalls/policy`, `auth/authentik/oidc_provider`, `storage/backup/schedule`.
- **New in-repo modules**: `auth/authentik/ldap_outpost`, `storage/seaweedfs/bucket`, `storage/seaweedfs/s3_user`.
- **Providers**: no new providers. `kubernetes`, `helm`, `kubectl`, `random`, `tls`, `authentik` are already declared/configured in `stacks/mantle/providers.tf` (authentik `goauthentik/authentik 2026.8.0`). Explicitly **not** using the AWS provider (bucket/user go through `weed shell`), so the seaweedfs release is untouched (no `-iam.readOnly` change).
- **Cluster deps already present**: SeaweedFS S3 (`kube-storage`, endpoint `s3.vn.linuxguru.net`), shared `kube-network/private` gateway (NGF 2.7.1), `letsencrypt` ClusterIssuer, `longhorn` StorageClass, Velero (`kube-backup`).
- **Tooling**: `kubectl` (for `local-exec` `weed shell`), `tofu`/`terraform`, `helm` (for `template` verification).

## [Testing]

- **Static**: `tofu fmt -recursive` and `tofu validate` in `terraform/stacks/mantle` and each new module.
- **Chart render**: `helm template owncloud owncloud/ocis --version 0.8.0 -f <rendered-values>` to (a) confirm the proxy service name for `proxy_service_name`, (b) confirm per-service pod labels for the backup selectors, and (c) catch required-value errors (`s3ng.endpoint/bucket`, LDAP base DNs).
- **Plan**: `tofu plan` in `stacks/mantle` — review that only `documents`-scoped resources are added; confirm the three PVCs, the Namespace, the ListenerSet/HTTPRoute/ReferenceGrant, the netpols, and the Velero Schedules.
- **Provision idempotency**: run `tofu apply` twice — second run must show no changes for `terraform_data.bucket`/`terraform_data.user` (same `random_password` ⇒ `s3.configure` upsert = no-op). Inspect `weed shell` output via `kubectl -n kube-storage exec … -- weed shell -master=… <<< 's3.user.show -name owncloud'`.
- **Smoke (post-apply)**:
  - `drive.vn.linuxguru.net` serves the oCIS web UI with a valid cert (gateway listener + cert-manager).
  - OIDC login round-trips against authentik; an `owncloud-user` account lands as `user`, an `owncloud-admin` account as `admin` (role assignment from the `groups` claim).
  - oCIS `storage-users` binds to the LDAP outpost (egress to `kube-auth:636`); users/groups are visible.
  - Upload a small file → confirm a blob lands in bucket `owncloud-storage` (e.g. `weed shell s3.bucket.list` + object count) and metadata appears under `/var/lib/ocis` on the `owncloud-metadata` PVC. Upload one file near the metadata PVC size to exercise the s3ng staging buffer.
  - Metrics: Prometheus scrapes oCIS (the metrics ingress policy); confirm targets are up.
  - Velero: the three Schedules appear and a first run completes (`kubectl -n kube-backup get schedule,backup`).
- **Lockdown checks**: from an unrelated namespace, a request to the oCIS proxy `:9200` times out (default-deny); the gateway path works; oCIS cannot reach the internet (`allow_internet=false`).

## [Implementation Order]

1. **`modules/auth/authentik/ldap_outpost`** — build + `tofu validate`. Verify the `authentik_provider_ldap`/`authentik_outpost`/RBAC resources against the live authentik API; record the actual LDAP service name, base DN, and bind DN.
2. **`modules/storage/seaweedfs/bucket`** and **`modules/storage/seaweedfs/s3_user`** — build the idempotent `provision.sh` drivers; test standalone with `tofu apply` (twice) against `owncloud-storage`; confirm re-runs are no-ops.
3. **`modules/documents` (parent + `owncloud` submodule)** — namespace, netpols, PVCs, `helm_release.ocis`, OIDC client, listener, backups, monitoring. Confirm `proxy_service_name` + backup selectors via `helm template`.
4. **`stacks/mantle/documents.tf`** — wire `module.documents`; `tofu fmt`/`validate`/`plan`.
5. **Apply in dependency order** — ldap_outpost → bucket/s3_user → documents (the parent's `depends_on` chains the rest).
6. **Smoke + lockdown tests** (see [Testing]); iterate on any chart-value or LDAP-mapping issues (the `oidc.userIDClaim` ↔ LDAP attribute match and the RBAC codename are the two likely trouble spots).

## [Open Questions / Assumptions]

- **Max upload file size** — drives `metadata_size` (s3ng stages uploads locally). Assumed **5Gi**; confirm or adjust (`1Gi` if all files are small; larger for big media).
- **LDAP bind user + RBAC** — the `authentik_rbac_permission_role` codename and the user↔role linkage may need a one-time UI step if the provider can't express them.
- **OIDC↔LDAP identity match** — `oidc.userIDClaim = "preferred_username"` mapped to the LDAP `uid` (`userIDClaimAttributeMapping = "username"`); confirm the authentik OIDC provider emits `preferred_username` (via the `profile` scope), else add a scope mapping.
- **`proxy_service_name`** — assumed `owncloud-proxy`; confirm from `helm template`.

## [Out of Scope]

- OCM federation (disabled).
- Internet egress and ollama/`ai` access (deferred; the egress module leaves an obvious slot to add later).
- Blob backup in SeaweedFS (the `owncloud-storage` data is protected by SeaweedFS 3× replication only; a bucket-level backup is a future item).
- Refactoring `modules/storage/backup` onto the new `bucket`/`s3_user` modules (left as-is).

