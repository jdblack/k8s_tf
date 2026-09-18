resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
  }
}

locals {
  helm_values = {
    externalURL = local.url,
    updateStrategy = {
      type = "Recreate"
    }
    harborAdminPassword = random_password.admin_password.result,
    persistence = {
      persistentVolumeClaim = {
        registry = {
          size         = "2Pi"
          storageClass = "seaweedfs-csi"
        }
        trivy = {
          size         = "2Pi"
          storageClass = "seaweedfs-csi"
        }

      }
    }
    expose = {
      type = "route"
      tls = {
        enabled = false
      }
      route = {
        parentRefs = [{
          name        = var.name
          namespace   = var.namespace
          group       = "gateway.networking.k8s.io"
          kind        = "ListenerSet"
          sectionName = var.name
        }]
        hosts = [local.fqdn]
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
        }
      }
    }
  }
}

resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = var.helm_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}
