locals {
  name_prefix = coalesce(var.name_prefix, "namespace-egress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

  kubeadm_configuration = try(
    yamldecode(data.kubernetes_config_map_v1.kubeadm[0].data["ClusterConfiguration"]),
    {}
  )

  pod_cidr = try(local.kubeadm_configuration.networking.podSubnet, null)

  service_cidr = try(local.kubeadm_configuration.networking.serviceSubnet, null)

  private_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  api_cluster_ip = try(data.kubernetes_service_v1.kubernetes[0].spec[0].cluster_ip, "")

  api_cluster_port = try(
    [for port in data.kubernetes_service_v1.kubernetes[0].spec[0].port : port.port if port.name == "https"][0],
    try(data.kubernetes_service_v1.kubernetes[0].spec[0].port[0].port, null),
  )

  api_endpoint_ips = distinct(compact(flatten([
    for subset in try(data.kubernetes_endpoints_v1.kubernetes[0].subset, []) : [
      for address in subset.address : address.ip
    ]
  ])))

  rule_self = var.allow_namespace ? {
    ports = []
    to    = [{ namespace = var.namespace }]
  } : null

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

  rules_namespaces = [
    for ns in distinct(var.to_namespaces) : {
      ports = []
      to    = [{ namespace = ns }]
    }
  ]

  rule_api_cluster_ip = var.allow_k8s_api && local.api_cluster_ip != "" && local.api_cluster_port != null ? {
    ports = [{ port = local.api_cluster_port, protocol = "TCP" }]
    to    = [{ ip_block = { cidr = "${local.api_cluster_ip}/32" } }]
  } : null

  rule_api_endpoints = var.allow_k8s_api && length(local.api_endpoint_ips) > 0 ? {
    ports = [{ port = 6443, protocol = "TCP" }]
    to    = [for ip in local.api_endpoint_ips : { ip_block = { cidr = "${ip}/32" } }]
  } : null

  rule_cluster = var.allow_cluster ? {
    ports = []
    to = [
      { ip_block = { cidr = local.pod_cidr } },
      { ip_block = { cidr = local.service_cidr } },
    ]
  } : null

  rule_internet = var.allow_internet ? {
    ports = []
    to    = [{ ip_block = { cidr = "0.0.0.0/0", except = local.private_cidrs } }]
  } : null

  cidr_peers = distinct(var.to_cidrs)

  rule_cidrs = length(local.cidr_peers) > 0 ? {
    ports = []
    to    = [for cidr in local.cidr_peers : { ip_block = { cidr = cidr } }]
  } : null

  egress = concat(
    local.rule_self != null ? [local.rule_self] : [],
    [local.rule_dns],
    local.rules_namespaces,
    local.rule_api_cluster_ip != null ? [local.rule_api_cluster_ip] : [],
    local.rule_api_endpoints != null ? [local.rule_api_endpoints] : [],
    local.rule_cluster != null ? [local.rule_cluster] : [],
    local.rule_internet != null ? [local.rule_internet] : [],
    local.rule_cidrs != null ? [local.rule_cidrs] : [],
  )
}
