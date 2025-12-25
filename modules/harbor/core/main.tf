
resource kubernetes_namespace_v1 namespace {
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
    caBundleSecretName =  local.ca_secret_name
    persistence = {
      persistentVolumeClaim = {
        registry = {
          size = "2Pi"
          storageClass = "seaweedfs-csi"
        }
        trivy = {
          size = "2Pi"
          storageClass = "seaweedfs-csi"
        }

      }
    }
    expose = {
      ingress = {
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = local.fqdn,
          "cert-manager.io/cluster-issuer" = var.cert_issuer,
        }
        className = "private"
        tls = {
          certSource = "secret"
          secretname = "${var.name}-cert"
        }
        hosts = {
          core = local.fqdn
        }
      }
    }
  }
}

resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  namespace  = var.namespace
  timeout = 500
  values = [yamlencode(local.helm_values)]

}

