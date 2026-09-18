data "kubernetes_config_map_v1" "kubeadm" {
  count = var.allow_cluster ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

data "kubernetes_service_v1" "kubernetes" {
  count = var.allow_k8s_api ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.allow_k8s_api ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
