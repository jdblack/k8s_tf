resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
  }
}

locals {

  values = {
    service = {
      type = "ClusterIP"
    }
    auth = {
      adminUser = var.adminUser
      existingSecret = "keycloak-credentials"
    }
    extraStartupArgs = "-Dkeycloak.profile.feature.docker=enabled"
    ingress = {
      enabled = true
      annotations = {
        "nginx.ingress.kubernetes.io/proxy-buffer-size" = "128k"
        "nginx.ingress.kubernetes.io/configuration-snippet" = <<-EOT
        more_set_headers "Host              $http_host";
        more_set_headers "X-Real-IP         $remote_addr";
        more_set_headers "X-Forwarded-Proto $scheme";
        more_set_headers "X-Forwarded-For   $proxy_add_x_forwarded_for";
        EOT
        "cert-manager.io/cluster-issuer" = var.cert_issuer
      }
      ingressClassName = var.ingress_class
      hostname = local.domain
      tls = [
        {
          secretName = "keycloak-cert"
          hosts = local.domains
        }
      ]
    }
  }
}

resource "helm_release" "release" {
  name  = var.name
  namespace = local.namespace
  repository = var.helm_url
  chart = local.chart
  values = [yamlencode(local.values)]
  depends_on = [
    kubernetes_secret.keycloak_secrets
  ]
}

resource random_password keycloak_admin {
  length = 15
  special = true
  override_special = "_%@"
}

resource kubernetes_secret keycloak_secrets {
  metadata {
    name = "keycloak-credentials"
    namespace = local.namespace
  }
  data = {
    "site" = "https://keycloak.vn.linuxguru.net"
    "admin-password" = local.password
    "admin-user" = var.adminUser
  }
}
