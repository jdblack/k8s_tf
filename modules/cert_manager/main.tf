resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "release" {
  name      = "cert-manager"
  namespace = var.namespace

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.helm_version

  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
  depends_on = [kubernetes_secret_v1.ca-key]
}
