locals {
  needs_cidrs   = var.to_cluster
  needs_api_ips = var.to_k8s_api && length(var.api_peer_ips) == 0
}

# kubeadm writes podSubnet/serviceSubnet here at bootstrap: the single source of truth the
# callers never have to know about.
data "kubernetes_config_map_v1" "kubeadm" {
  count = local.needs_cidrs ? 1 : 0

  metadata {
    name      = "kubeadm-config"
    namespace = "kube-system"
  }
}

# Two things answer for "where is the API server": the Service's ClusterIP (what an in-cluster
# client's DNS resolves to) and the Endpoints behind it (where kube-proxy actually sends it).
# Both are needed -- a rule with only the ClusterIP breaks clients that get reconciled to a
# node, and a rule with only the endpoint breaks clients that never set a Host. Note `spec` is
# a list *attribute*, not a block, in provider 3.x: hence `spec[0].cluster_ip`.
# Deprecated Endpoints API, still served -- hence var.api_peer_ips as the escape hatch.
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
