resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
  }
}

resource "helm_release" "release" {
  name  = var.name
  namespace = local.namespace
  repository = var.helm_url
  chart = local.chart
}

