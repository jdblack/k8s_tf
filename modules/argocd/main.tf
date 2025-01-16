
resource "kubernetes_namespace" "argocd" {
  metadata { 
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = var.namespace

  # Encode local.config to YAML for Helm values
  values = [yamlencode(local.config)]
}


data "kubernetes_secret" "initial_admin_pass" {
  metadata {
    name = "argocd-initial-admin-secret"
    namespace =var.namespace
  }
  depends_on = [ helm_release.argocd ]
}


output "admin_pass" {
  value = data.kubernetes_secret.initial_admin_pass.data.password
}


