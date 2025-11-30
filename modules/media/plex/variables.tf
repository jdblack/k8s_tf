variable plex_name { default = "plex" }
variable chart_version { default = "1.3.0" }
variable namespace { type = string }


locals {
  plex_host_internal = "${var.plex_name}.linuxguru.net"

  plex_helm_values = {
    extraEnv = {
//      ADVERTISE_IP = "http://192.168.0.104:32400, http://113.161.41.162:32400"
      PLEX_UID = 1000
      PLEX_GID = 1000
    }
    pms = {
      configStorage = "3Gi"
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
    ingress = {
      enabled = true
      ingressClassName = "public"
      url = local.plex_host_internal
      annotatons = {
        "cert-manager.io/cluster-issuer" = "letsencrypt",
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
//      annotations = {
//        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal,
//      }
    }
  }
}


