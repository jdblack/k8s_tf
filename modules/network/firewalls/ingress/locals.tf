locals {
  # Explicit name wins outright; otherwise name_prefix (namespace-ingress) + a generated 8-hex suffix,
  # so a namespace with several calls can omit both. try() covers random_id's count = 0 branch.
  name_prefix = coalesce(var.name_prefix, "namespace-ingress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

  # kubeadm stores the ClusterConfiguration as a YAML string under this key.
  kubeadm_configuration = try(
    yamldecode(data.kubernetes_config_map_v1.kubeadm[0].data["ClusterConfiguration"]),
    {}
  )

  # Authoritative and read-only: kubeadm wrote podSubnet (= the Calico IPPool) here at bootstrap.
  pod_cidr = try(local.kubeadm_configuration.networking.podSubnet, null)

  # RFC1918 + link-local. Subtracting these is what keeps allow_internet off the LAN, off every pod and
  # off the ClusterIPs -- nothing in-cluster has a public source address.
  private_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  # Sources on a node's host network, v4 only (/32 is right for one and wrong for a v6 address): kubelet
  # probes, apiserver -> pod, and the node-SNAT'd side of an externalTrafficPolicy=Cluster LoadBalancer.
  # TWO addresses per node, because a host-netns source arrives as one of two different addresses
  # depending on where its target lives: the InternalIP when the pod is on the same node, and the Calico
  # IPIP tunnel address when it is not -- Calico MASQUERADEs that traffic on the way out of tunl0, so a
  # pod on another node sees the *sending* node's tunnel address, an address inside the pod CIDR that no
  # namespaceSelector can ever name. With InternalIP alone, every cross-node apiserver -> pod call (an
  # admission webhook, i.e. cert-manager's) reads as a stranger and the curtain drops it: measured
  # 2026-09-17 on `cert-manager-webhook`, `.clinedocs/calico-netpols.md`.
  node_ips = distinct(compact(flatten([
    for node in try(data.kubernetes_nodes.this[0].nodes, []) : concat(
      [for address in try(node.status[0].addresses, []) : address.address
      if address.type == "InternalIP" && !strcontains(address.address, ":")],
      [for ip in [try(node.metadata[0].annotations["projectcalico.org/IPv4IPIPTunnelAddr"], "")] : ip
      if !strcontains(ip, ":")],
    )
  ])))

  # Self is on unless the call site turns it off: intra-namespace traffic is implicit in nearly every app,
  # and losing it looks like a broken application rather than like policy.
  rule_self = var.allow_namespace ? {
    ports = []
    from  = [{ namespace = var.namespace }]
  } : null

  # distinct(), like from_cidrs: a name repeated twice is still one peer.
  rules_namespaces = [
    for ns in distinct(var.from_namespaces) : {
      ports = []
      from  = [{ namespace = ns }]
    }
  ]

  # A rule with no `from` peers means "from anywhere", so a failed read drops it -- an empty peer set
  # would open the pods to every source on that port.
  rule_nodes = var.allow_nodes && length(local.node_ips) > 0 ? {
    ports = []
    from  = [for ip in local.node_ips : { ip_block = { cidr = "${ip}/32" } }]
  } : null

  # A source is never a ClusterIP -- DNAT rewrites the destination address, not the source -- so where
  # the egress direction carries a second service-CIDR peer, this one has only the pod CIDR.
  rule_cluster = var.allow_cluster ? {
    ports = []
    from  = [{ ip_block = { cidr = local.pod_cidr } }]
  } : null

  # Public sources only. A WAN-forwarded LoadBalancer is what this is for; `0.0.0.0/0` bare would also
  # admit every pod, the LAN and the nodes.
  rule_internet = var.allow_internet ? {
    ports = []
    from  = [{ ip_block = { cidr = "0.0.0.0/0", except = local.private_cidrs } }]
  } : null

  # distinct() so a call site that names the same CIDR twice renders one peer, not two.
  cidr_peers = distinct(var.from_cidrs)

  rule_cidrs = length(local.cidr_peers) > 0 ? {
    ports = []
    from  = [for cidr in local.cidr_peers : { ip_block = { cidr = cidr } }]
  } : null

  # One rule per guest, so `ports` stays the guest's own. `pod_selector` is merged in only when given:
  # a `from` entry with namespaceSelector AND podSelector is an AND in a single peer.
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

  # Render order, frozen -- this list IS the rendered spec: self (unless allow_namespace = false) ->
  # from_namespaces -> nodes -> cluster -> internet -> from_cidrs -> from_peers. The narrow, exactly
  # named guests come last, after the switches. Nothing here renders an empty list for a call that
  # named a guest; a call that names none renders `ingress = []` = deny-all inbound.
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
