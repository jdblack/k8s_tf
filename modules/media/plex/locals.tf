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
      # Web UI exposure moved to the shared public gateway (listener.tf); the
      # chart just keeps the LoadBalancer service for direct PMS access (32400).
      enabled = false
    }
    service = {
      type = "LoadBalancer"
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal,
      }
    }
  }
}