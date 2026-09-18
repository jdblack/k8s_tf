locals {
  plex_host_internal = "${var.plex_name}.${var.domain}"
  helm_values = {
    extraEnv = {
      PLEX_CLAIM = var.plex_claim
      PLEX_UID   = 1000
      PLEX_GID   = 1000
    }
    pms = {
      configStorage = "30Gi"
    }
    image = {
      tag        = "latest"
      pullPolicy = "Always"
    }
    extraVolumes = [
      {
        name = "media"
        persistentVolumeClaim = {
          claimName = var.movies_pvc
        }
      }
    ]
    extraVolumeMounts = [
      {
        name      = "media"
        mountPath = "/media"
      }
    ]
    ingress = {
      enabled = false
    }
    service = {
      type                  = "LoadBalancer"
      externalTrafficPolicy = "Local"
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal,
      }
    }
  }
}
