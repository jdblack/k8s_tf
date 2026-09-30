data "kubernetes_nodes" "all" {
  count = var.direction == "ingress" ? 1 : 0
}

data "kubernetes_service_v1" "kubernetes" {
  count = var.direction == "egress" && var.allow_k8s_api ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.direction == "egress" && var.allow_k8s_api ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
