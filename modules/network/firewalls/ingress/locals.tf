locals {
  name_prefix = coalesce(var.name_prefix, "namespace-ingress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

  kubeadm_configuration = try(
    yamldecode(data.kubernetes_config_map_v1.kubeadm[0].data["ClusterConfiguration"]),
    {}
  )

  pod_cidr = try(local.kubeadm_configuration.networking.podSubnet, null)

  private_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  # Sorted: the API's node order is not stable, and an unsorted ip_block list shows
  # up as plan churn on every namespace-wide policy.
  node_ips = sort(distinct(compact(flatten([
    for node in try(data.kubernetes_nodes.this[0].nodes, []) : concat(
      [for address in try(node.status[0].addresses, []) : address.address
      if address.type == "InternalIP" && !strcontains(address.address, ":")],
      [for ip in [try(node.metadata[0].annotations["projectcalico.org/IPv4IPIPTunnelAddr"], "")] : ip
      if !strcontains(ip, ":")],
    )
  ]))))

  rule_self = var.allow_namespace ? {
    ports = []
    from  = [{ namespace = var.namespace }]
  } : null

  rules_namespaces = [
    for ns in distinct(var.from_namespaces) : {
      ports = []
      from  = [{ namespace = ns }]
    }
  ]

  rule_nodes = var.allow_nodes && length(local.node_ips) > 0 ? {
    ports = []
    from  = [for ip in local.node_ips : { ip_block = { cidr = "${ip}/32" } }]
  } : null

  rule_cluster = var.allow_cluster ? {
    ports = []
    from  = [{ ip_block = { cidr = local.pod_cidr } }]
  } : null

  rule_internet = var.allow_internet ? {
    ports = []
    from  = [{ ip_block = { cidr = "0.0.0.0/0", except = local.private_cidrs } }]
  } : null

  cidr_peers = distinct(var.from_cidrs)

  rule_cidrs = length(local.cidr_peers) > 0 ? {
    ports = []
    from  = [for cidr in local.cidr_peers : { ip_block = { cidr = cidr } }]
  } : null

  rules_peers = [
    for peer in var.from_peers : {
      ports = peer.ports
      from = [merge(
        { namespace = peer.namespace },
        peer.pod_selector != null ? { pod_selector = peer.pod_selector } : {},
        length(peer.pod_selector_expressions) > 0 ? { pod_selector_expressions = peer.pod_selector_expressions } : {},
      )]
    }
  ]

  ingress = concat(
    local.rule_self != null ? [local.rule_self] : [],
    local.rules_namespaces,
    local.rule_nodes != null ? [local.rule_nodes] : [],
    local.rule_cluster != null ? [local.rule_cluster] : [],
    local.rule_internet != null ? [local.rule_internet] : [],
    local.rule_cidrs != null ? [local.rule_cidrs] : [],
    local.rules_peers,
  )
}
