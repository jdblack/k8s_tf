locals {
  plex_host_internal = "${var.plex_name}.${var.domain}"
  plex_helm_values = {
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
      enabled          = true
      ingressClassName = "public"
      url              = local.plex_host_internal
      annotations = {
        "cert-manager.io/cluster-issuer"            = var.cert_issuer,
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal,
      }
      tls = [
        {
          hosts      = [local.plex_host_internal]
          secretName = "cert-${local.plex_host_internal}"
        }
      ]
      hosts = [
        {
          host = local.plex_host_internal
          paths = [
            {
              path     = "/"
              pathType = "ImplementationSpecific"
            }
          ]
        }
      ]
    }
    service = {
      type = "LoadBalancer"
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal,
      }
    }
  }
}