locals {
  private_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  # Sorted: the API's node order is not stable, and an unsorted ip_block list is plan churn.
  node_ips = sort(distinct(compact(flatten([
    for node in try(data.kubernetes_nodes.all[0].nodes, []) : concat(
      [for address in try(node.status[0].addresses, []) : address.address
      if address.type == "InternalIP" && !strcontains(address.address, ":")],
      [for ip in [try(node.metadata[0].annotations["projectcalico.org/IPv4IPIPTunnelAddr"], "")] : ip
      if !strcontains(ip, ":")],
    )
  ]))))

  pod_selector = length(var.pod_selector) > 0 ? var.pod_selector : null

  rule_self = var.allow_namespace ? { ports = [], peers = [{ namespace = var.namespace }] } : null

  rule_dns = {
    ports = [{ port = 53, protocol = "UDP" }, { port = 53, protocol = "TCP" }]
    peers = [{ namespace = "kube-system", pod_selector = { "k8s-app" = "kube-dns" } }]
  }

  rule_nodes = {
    ports = []
    peers = [for ip in local.node_ips : { ip_block = { cidr = "${ip}/32" } }]
  }

  rule_internet = {
    ports = []
    peers = [{ ip_block = { cidr = "0.0.0.0/0", except = local.private_cidrs } }]
  }

  rules_peers = [for peer in var.peers : {
    ports = peer.ports
    peers = [merge(
      { namespace = peer.namespace },
      peer.pod_selector != null ? { pod_selector = peer.pod_selector } : {},
      length(peer.pod_selector_expressions) > 0 ? { pod_selector_expressions = peer.pod_selector_expressions } : {},
    )]
  }]

  api_cluster_ip = try(data.kubernetes_service_v1.kubernetes[0].spec[0].cluster_ip, "")

  api_cluster_port = try(
    [for port in data.kubernetes_service_v1.kubernetes[0].spec[0].port : port.port if port.name == "https"][0],
    try(data.kubernetes_service_v1.kubernetes[0].spec[0].port[0].port, null),
  )

  api_endpoint_ips = sort(distinct(compact(flatten([
    for subset in try(data.kubernetes_endpoints_v1.kubernetes[0].subset, []) : [
      for address in subset.address : address.ip
    ]
  ]))))

  # A /32 stops matching the moment DHCP moves the control-plane node, so widen to the surrounding subnet.
  api_endpoint_cidrs = distinct([
    for ip in local.api_endpoint_ips : cidrsubnet("${ip}/${var.api_endpoint_prefix_length}", 0, 0)
  ])

  rule_api_cluster_ip = var.allow_k8s_api && local.api_cluster_ip != "" && local.api_cluster_port != null ? {
    ports = [{ port = local.api_cluster_port, protocol = "TCP" }]
    peers = [{ ip_block = { cidr = "${local.api_cluster_ip}/32" } }]
  } : null

  rule_api_endpoints = var.allow_k8s_api && length(local.api_endpoint_cidrs) > 0 ? {
    ports = [{ port = 6443, protocol = "TCP" }]
    peers = [for cidr in local.api_endpoint_cidrs : { ip_block = { cidr = cidr } }]
  } : null

  rules = concat(
    local.rule_self != null ? [local.rule_self] : [],
    var.direction == "ingress" && length(local.node_ips) > 0 ? [local.rule_nodes] : [],
    var.direction == "egress" ? [local.rule_dns] : [],
    var.direction == "egress" && local.rule_api_cluster_ip != null ? [local.rule_api_cluster_ip] : [],
    var.direction == "egress" && local.rule_api_endpoints != null ? [local.rule_api_endpoints] : [],
    var.allow_internet ? [local.rule_internet] : [],
    local.rules_peers,
  )
}
