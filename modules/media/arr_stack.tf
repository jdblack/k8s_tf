locals {
  media_volume = [{
    name                  = "media"
    persistentVolumeClaim = { claimName = var.movies_pvc }
  }]

  media_mount = [{ name = "media", mountPath = "/media" }]

  arr_run_as = { runAsUser = 1000, runAsGroup = 1000 }

  arr_config = { persistence = { size = "1Gi" } }

  # Velero fs-backup is opt-in per pod volume, and `config` is each arr chart's own volume name.
  arr_backup_annotations = { "backup.velero.io/backup-volumes" = "config" }

  # Prefer the node where Plex (labelled movies-archive=anchor) runs, so every library
  # consumer shares that node's single node-local SeaweedFS read cache.
  anchor_affinity = {
    podAffinity = {
      preferredDuringSchedulingIgnoredDuringExecution = [{
        weight = 100
        podAffinityTerm = {
          labelSelector = { matchLabels = { "movies-archive" = "anchor" } }
          topologyKey   = "kubernetes.io/hostname"
        }
      }]
    }
    # Keep the stack off the controller node (no control-plane label/taint here, so
    # exclude k8smaster by hostname) -- paired with the preferred podAffinity above so
    # every consumer lands on Plex's node and shares its node-local read cache.
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [{
          matchExpressions = [{
            key      = "kubernetes.io/hostname"
            operator = "NotIn"
            values   = ["k8smaster"]
          }]
        }]
      }
    }
  }
}

module "radarr" {
  source = "./media_app"

  namespace         = var.namespace
  name              = "radarr"
  helm_repo         = "oci://ghcr.io/m0nsterrr/helm-charts"
  chart             = "radarr"
  helm_version      = "3.6.4"
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = local.auth_outpost

  helm_values = {
    volumes         = local.media_volume
    volumeMounts    = local.media_mount
    config          = local.arr_config
    podAnnotations  = local.arr_backup_annotations
    securityContext = local.arr_run_as
    affinity        = local.anchor_affinity
  }
}

module "sonarr" {
  source = "./media_app"

  namespace         = var.namespace
  name              = "sonarr"
  helm_repo         = "oci://ghcr.io/m0nsterrr/helm-charts"
  chart             = "sonarr"
  helm_version      = "2.2.3"
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = local.auth_outpost

  helm_values = {
    image           = { tag = "4", pullPolicy = "Always" }
    volumes         = local.media_volume
    volumeMounts    = local.media_mount
    config          = local.arr_config
    podAnnotations  = local.arr_backup_annotations
    securityContext = local.arr_run_as
    affinity        = local.anchor_affinity
  }
}

module "prowlarr" {
  source = "./media_app"

  namespace         = var.namespace
  name              = "prowlarr"
  helm_repo         = "oci://ghcr.io/m0nsterrr/helm-charts"
  chart             = "prowlarr"
  helm_version      = "3.8.4"
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = local.auth_outpost

  helm_values = {
    ingress        = { enabled = false }
    podAnnotations = local.arr_backup_annotations
  }
}

module "bazarr" {
  source = "./media_app"

  namespace         = var.namespace
  name              = "bazarr"
  helm_repo         = "oci://ghcr.io/m0nsterrr/helm-charts"
  chart             = "bazarr"
  helm_version      = "2.3.1"
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = local.auth_outpost

  helm_values = {
    image           = { pullPolicy = "Always" }
    volumes         = local.media_volume
    volumeMounts    = local.media_mount
    config          = local.arr_config
    podAnnotations  = local.arr_backup_annotations
    securityContext = local.arr_run_as
    affinity        = local.anchor_affinity
  }
}

module "seerr" {
  source = "./media_app"

  namespace         = var.namespace
  name              = "seerr"
  helm_repo         = "oci://ghcr.io/seerr-team/seerr"
  chart             = "seerr-chart"
  helm_version      = "3.9.1"
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = null

  helm_values = {
    nameOverride   = "seerr"
    config         = { persistence = { size = "2Gi" } }
    podAnnotations = local.arr_backup_annotations
    route          = { main = { enabled = false } }
  }
}

# Launcher-only tile: seerr keeps its own login, so no SSO proxy fronts it. It still gets
# its own seerr-admin/seerr-user pair like every other app.
module "seerr_tile" {
  source = "../auth/authentik/application"

  name       = "seerr"
  slug       = "seerr"
  launch_url = "https://seerr.${var.domain}"
  icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/seerr.svg"
}

module "qbittorrent" {
  source = "./qbittorrent"

  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = local.auth_outpost
  torrent_lb_ip     = var.qbittorrent_torrent_lb_ip
}

module "suggestarr" {
  source = "./suggestarr"

  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_outpost      = local.auth_outpost

  # dashboard-icons has no suggestarr mark, so this one comes from the selfh.st set.
  icon      = "https://cdn.jsdelivr.net/gh/selfhst/icons/svg/suggestarr.svg"
  pod_cidr  = var.pod_cidr
  host_cidr = var.host_cidr
}

module "unpackerr" {
  source         = "./unpackerr"
  namespace      = var.namespace
  movies_pvc     = var.movies_pvc
  sonarr_api_key = var.sonarr_api_key
  radarr_api_key = var.radarr_api_key
}
