locals {
  needs_cidrs = var.allow_cluster
  needs_nodes = var.allow_nodes
}

data "kubernetes_config_map_v1" "kubeadm" {
  count = local.needs_cidrs ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

data "kubernetes_nodes" "this" {
  count = local.needs_nodes ? 1 : 0
}
