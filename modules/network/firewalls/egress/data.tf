locals {
  needs_cidrs   = var.allow_cluster
  needs_api_ips = var.allow_k8s_api
}

data "kubernetes_config_map_v1" "kubeadm" {
  count = local.needs_cidrs ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

data "kubernetes_service_v1" "kubernetes" {
  count = local.needs_api_ips ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

data "kubernetes_endpoints_v1" "kubernetes" {
  count = local.needs_api_ips ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
