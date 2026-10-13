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
    namespace = var.deployment.argo.namespace
    name      = var.deployment.argo.auth_secret
  }
}

# The break-glass local admin the Forgejo chart mints. The instance lives in `core` now, so this
# stack only reads it (the runner's registration-token data source reads the same Secret). Both
# halves are here, which is what the forgejo provider needs.
data "kubernetes_secret_v1" "forgejo_admin" {
  metadata {
    namespace = "devops-forgejo"
    name      = "forgejo-admin"
  }
}
