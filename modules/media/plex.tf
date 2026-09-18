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
  backend_port      = 32400

  helm_values = {
    extraEnv = {
      PLEX_CLAIM = var.plex_claim
      PLEX_UID   = 1000
      PLEX_GID   = 1000
    }
    pms   = { configStorage = "30Gi" }
    image = { tag = "latest", pullPolicy = "Always" }

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
