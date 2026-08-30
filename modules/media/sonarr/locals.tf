locals {
  fqdn      = "${var.name}.${var.domain}"
  cert_name = "cert-${var.name}.${var.domain}"

  helm_values = {
    image = {
      tag             = "4"
      imagePullPolicy = "Always"
    }
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
      runAsUser  = 1000
      runAsGroup = 1000
    }
    route = {
      main = {
        enabled   = true
        hostnames = [local.fqdn]
        parentRefs = [
          {
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

