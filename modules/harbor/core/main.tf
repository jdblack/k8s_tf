
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
    caBundleSecretName  = local.ca_secret_name
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
      # Chart-native Gateway API HTTPRoute (expose.type = "route"): the shared
      # private gateway terminates TLS and the chart routes /api/, /service/,
      # /v2/, /c/ to harbor-core and / to harbor-portal -- matching the old
      # ingress path routing exactly.
      type = "route"
      tls = {
        enabled = false
      }
      route = {
        # NGF only attaches routes to listeners contributed by ListenerSets
        # when the route parentRefs the ListenerSet itself (not the Gateway),
        # so point the chart-rendered HTTPRoute at our ListenerSet.
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
  namespace  = var.namespace
  timeout    = 500
  values     = [yamlencode(local.helm_values)]

}

