
variable "name" { default = "external-secrets" }
variable "helm_repo" { default = "https://charts.external-secrets.io" }
variable "chart" { default = "external-secrets" }
variable "namespace" { default = "kube-secrets" }
variable "namespace_create" { default = true }

locals {
  helm_values = {}
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
  count = var.namespace_create ? 1 : 0
}


resource "helm_release" "release" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  namespace  = var.namespace
  values     = [yamlencode(local.helm_values)]
  depends_on = [kubernetes_namespace.namespace]
}

