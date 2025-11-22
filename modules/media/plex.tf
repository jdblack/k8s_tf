variable plex_name { default = "plex" }


resource helm_release plex {
  name  = "plex"
  repository = "https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages"
  chart = "plex-media-server"
  namespace = var.namespace
  depends_on = [ kubernetes_namespace.namespace ]
  values = [yamlencode(local.plex_helm_values)]
}

locals {
  plex_domain = "${var.plex_name}.linuxguru.net"

  plex_helm_values = {
    extraEnv = {
      PLEX_CLAIM = "claim-QGWta2v1tJsuBsiyvfwA"
      PLEX_UID = 0
      PLEX_GID = 0
    }
    image = {
      tag = "latest"
    }
    pullPolicy = "always"
    extraVolumes = [
      {
        name = "media"
        persistentVolumeClaim = {
          claimName = "movies"
        }
      }
    ]
    extraVolumeMounts = [
      {
        name      = "media"
        mountPath = "/media"
      }
    ]
    service = {
      type = "LoadBalancer"
    }
  }
}

