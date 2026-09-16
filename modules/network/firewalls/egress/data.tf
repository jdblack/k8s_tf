locals {
  needs_cidrs   = var.allow_cluster
  needs_api_ips = var.allow_k8s_api
}

# kubeadm writes podSubnet/serviceSubnet here at bootstrap: the single source of truth callers never see.
data "kubernetes_config_map_v1" "kubeadm" {
  count = local.needs_cidrs ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

# Two things answer for "where is the API server": the Service's ClusterIP (what a client's DNS
# resolves to) and the Endpoints behind it (where kube-proxy actually sends it), and both are needed.
# `spec` is a list *attribute*, not a block, in provider 3.x: hence `spec[0].cluster_ip`.
# Deprecated Endpoints API, still served.
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
