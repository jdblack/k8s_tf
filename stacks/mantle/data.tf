data "kubernetes_secret_v1" "harbor_auth" {
  metadata {
    namespace = var.deployment.harbor.namespace
    name      = var.deployment.harbor.auth_secret
  }
}

data "kubernetes_secret_v1" "authentik_auth" {
  metadata {
    namespace = var.deployment.auth.namespace
    name      = var.deployment.auth.authentik_api_key
  }
}

data "kubernetes_secret_v1" "argocd_auth" {
  metadata {
    namespace = var.deployment.argocd_devops.namespace
    name      = var.deployment.argocd_devops.auth_secret
  }
}
