locals {
  needs_cidrs = var.allow_cluster
  needs_nodes = var.allow_nodes
}

# kubeadm writes podSubnet/serviceSubnet here at bootstrap: the single source of truth callers never see.
data "kubernetes_config_map_v1" "kubeadm" {
  count = local.needs_cidrs ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

# The node addresses, and the reason this direction has a floor the egress one does not need: kubelet
# health probes and the apiserver's own calls into a pod start on the node, never on a pod.
data "kubernetes_nodes" "this" {
  count = local.needs_nodes ? 1 : 0
}
