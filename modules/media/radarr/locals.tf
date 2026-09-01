locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    volumes = [
      {
        name = "media"
        persistentVolumeClaim = {
          claimName = var.movies_pvc
        }
      }
    ]
    volumeMounts = [
      {
        name      = "media"
        mountPath = "/media"
      }
    ]
    config = {
      persistence = {
        size = var.config_size
      }
    }
    securityContext = {
      runAsUser = 1000
    }
    route = {
      main = {
        enabled   = true
        hostnames = [local.fqdn]
        parentRefs = [
          {
            group       = "gateway.networking.k8s.io"
            kind        = "ListenerSet"
            name        = var.name
            namespace   = var.namespace
            sectionName = var.name
          }
        ]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
        }
      }
    }
  }
}

