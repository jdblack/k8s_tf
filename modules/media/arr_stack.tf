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
  icon              = ""
  pod_cidr          = var.pod_cidr
  host_cidr         = var.host_cidr
}

module "unpackerr" {
  source         = "./unpackerr"
  namespace      = var.namespace
  movies_pvc     = var.movies_pvc
  sonarr_api_key = var.sonarr_api_key
  radarr_api_key = var.radarr_api_key
}
