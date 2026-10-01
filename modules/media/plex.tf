locals {
  plex_host = "plex.${var.domains["public"]}"
}

module "plex" {
  source = "./media_app"

  namespace         = var.namespace
  name              = "plex"
  helm_repo         = "https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages"
  chart             = "plex-media-server"
  helm_version      = "1.9.0"
  domain            = var.domains["public"]
  cert_issuer       = var.cert_issuer
  gateway_name      = "public"
  gateway_namespace = "kube-network"
  backend_name      = "plex-plex-media-server"
  port              = 32400
  auth_outpost      = null

  helm_values = {
    extraEnv = {
      PLEX_CLAIM = var.plex_claim
      PLEX_UID   = local.arr_run_as.runAsUser
      PLEX_GID   = local.arr_run_as.runAsGroup
    }
    pms   = { configStorage = "30Gi" }
    image = { tag = "latest", pullPolicy = "Always" }

    # Anchor label for co-location: the other library consumers use podAffinity to
    # follow this pod's node so they all share one node-local SeaweedFS read cache.
    commonLabels = { "movies-archive" = "anchor" }

    # Keep the media stack off the controller node: k8smaster has no control-plane
    # label or taint, so exclude it by hostname.
    affinity = {
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

    # Velero fs-backup is opt-in per pod volume; `pms-config` is the chart's own volume name.
    statefulSet = { podAnnotations = { "backup.velero.io/backup-volumes" = "pms-config" } }

    extraVolumes = [{
      name                  = "media"
      persistentVolumeClaim = { claimName = var.movies_pvc }
    }]
    extraVolumeMounts = [{ name = "media", mountPath = "/media" }]

    ingress = { enabled = false }
    service = {
      type                  = "LoadBalancer"
      externalTrafficPolicy = "Local"
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host
      }
    }
  }
}
