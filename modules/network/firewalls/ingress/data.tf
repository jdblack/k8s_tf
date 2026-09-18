data "kubernetes_config_map_v1" "kubeadm" {
  count = var.allow_cluster ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

data "kubernetes_nodes" "this" {
  count = var.allow_nodes ? 1 : 0
}
