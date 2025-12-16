resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "release" {
  name       = "cert-manager"
  namespace = var.namespace

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set = [ 
    {
      name = "installCRDs" 
      value = true
    }
  ]
  depends_on = [ kubernetes_secret.ca-key]
}

