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
  # Pinned to what the cluster already runs. The chart was floating (v1.21.2 is
  # published) -- an unpinned release would upgrade cert-manager and the ACME
  # config change in the same apply. Bump deliberately, one version at a time.
  version = "v1.21.1"

  values     = [yamlencode(local.helm_values)]
  depends_on = [kubernetes_secret_v1.ca-key]
}

