locals {
  fqdn      = "${var.name}.${var.domain}"
  helm_values = {
    image = {
      pullPolicy = "Always"
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
      runAsUser = 1000
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

resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  version    = "2.3.0"
  chart      = var.chart
  namespace  = var.namespace
  values     = [yamlencode(local.helm_values)]
}

