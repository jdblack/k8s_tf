locals {
  # kubeadm stores the ClusterConfiguration as a YAML string under this key.
  kubeadm_configuration = try(
    yamldecode(data.kubernetes_config_map_v1.kubeadm[0].data["ClusterConfiguration"]),
    {}
  )

  # Authoritative and read-only: kubeadm wrote podSubnet (= the Calico IPPool) and serviceSubnet
  # (= the apiserver's --service-cluster-ip-range) here at bootstrap, and both were checked
  # against the live cluster. No override exists on purpose -- a second source is a second thing
  # to drift.
  pod_cidr = try(local.kubeadm_configuration.networking.podSubnet, null)

  service_cidr = try(local.kubeadm_configuration.networking.serviceSubnet, null)

  # RFC1918 + link-local. Also the reason to_internet never reaches the LAN.
  private_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  # ClusterIP first, then the endpoints, so the rendered `to` order matches the live policies.
  api_cluster_ip = try(data.kubernetes_service_v1.kubernetes[0].spec[0].cluster_ip, "")

  api_ips = length(var.api_peer_ips) > 0 ? var.api_peer_ips : distinct(compact(concat(
    [local.api_cluster_ip],
    flatten([
      for subset in try(data.kubernetes_endpoints_v1.kubernetes[0].subset, []) : [
        for address in subset.address : address.ip
      ]
    ]),
  )))

  # --- floor: always rendered, no knob can remove it -------------------------------------
  rule_self = {
    ports = []
    to    = [{ namespace = var.namespace }]
  }

  rule_dns = {
    ports = [
      { port = 53, protocol = "UDP" },
      { port = 53, protocol = "TCP" },
    ]
    to = [{
      namespace    = "kube-system"
      pod_selector = { "k8s-app" = "kube-dns" }
    }]
  }

  # --- knobs -----------------------------------------------------------------------------
  rules_namespaces = [
    for ns in var.to_namespaces : {
      ports = []
      to    = [{ namespace = ns }]
    }
  ]

  rule_api = var.to_k8s_api ? {
    ports = [{ port = 6443, protocol = "TCP" }]
    to    = [for ip in local.api_ips : { ip_block = { cidr = "${ip}/32" } }]
  } : null

  rule_cluster = var.to_cluster ? {
    ports = []
    to = [
      { ip_block = { cidr = local.pod_cidr } },
      { ip_block = { cidr = local.service_cidr } },
    ]
  } : null

  rule_internet = var.to_internet ? {
    ports = []
    to    = [{ ip_block = { cidr = "0.0.0.0/0", except = local.private_cidrs } }]
  } : null

  rule_cidrs = length(var.to_cidrs) > 0 ? {
    ports = []
    to    = [for cidr in var.to_cidrs : { ip_block = { cidr = cidr } }]
  } : null

  # --- render order: frozen, this list IS the rendered spec -------------------------------
  egress = concat(
    [local.rule_self, local.rule_dns],
    local.rules_namespaces,
    local.rule_api != null ? [local.rule_api] : [],
    local.rule_cluster != null ? [local.rule_cluster] : [],
    local.rule_internet != null ? [local.rule_internet] : [],
    local.rule_cidrs != null ? [local.rule_cidrs] : [],
  )
}
