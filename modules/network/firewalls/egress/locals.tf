locals {
  # --- name ---------------------------------------------------------------------------------
  # An explicit name wins outright. Otherwise name_prefix (namespace-egress by default) plus a
  # generated 8-hex suffix, so a namespace with several calls can omit both and still get
  # distinct objects. try() covers random_id's count = 0 branch, same idiom as the reads below.
  name_prefix = coalesce(var.name_prefix, "namespace-egress")
  name        = coalesce(var.name, "${local.name_prefix}-${try(random_id.suffix[0].hex, "")}")

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

  # RFC1918 + link-local. Also the reason allow_internet never reaches the LAN.
  private_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  # ClusterIP first, then the endpoints, so the rendered rule order matches the live policies.
  api_cluster_ip = try(data.kubernetes_service_v1.kubernetes[0].spec[0].cluster_ip, "")

  # The ClusterIP answers on the *Service* port, not the apiserver's bind port: nothing serves
  # 6443 on 10.96.0.1 (checked live: :443 -> 200, :6443 -> timeout). Read off the live Service,
  # name-first, so a second port on it cannot shadow the right one. Null when the read fails,
  # which drops the rule (see rule_api_cluster_ip).
  api_cluster_port = try(
    [for port in data.kubernetes_service_v1.kubernetes[0].spec[0].port : port.port if port.name == "https"][0],
    try(data.kubernetes_service_v1.kubernetes[0].spec[0].port[0].port, null),
  )

  api_endpoint_ips = distinct(compact(flatten([
    for subset in try(data.kubernetes_endpoints_v1.kubernetes[0].subset, []) : [
      for address in subset.address : address.ip
    ]
  ])))

  # --- no peer list required ---------------------------------------------------------------
  # Self is on unless the call site turns it off (allow_namespace). DNS has no knob at all --
  # a pod-scoped policy that silently loses DNS looks like a broken application.
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

  # --- knobs -----------------------------------------------------------------------------
  # distinct(), like to_cidrs: a name repeated twice is still one peer.
  rules_namespaces = [
    for ns in distinct(var.to_namespaces) : {
      ports = []
      to    = [{ namespace = ns }]
    }
  ]

  # A rule with no `to` peers means "all destinations" to the API, so an unresolvable read has
  # to drop the rule rather than render an empty one: an API rule that silently widens to
  # anywhere-on-6443 would be the one way this module could ever allow more than it was asked.
  #
  # Two rules, not one: `ports` is shared by every peer in a rule, and the two API peers answer
  # on different ports (the Service's 443, the apiserver's 6443).
  #
  # Which of the two *matches* is a dataplane property, not a choice: kube-proxy DNATs a ClusterIP
  # dial to an endpoint before our policy chain runs, so on this cluster (iptables) the flow reads
  # <node-ip>:6443. Measured, one scratch policy per port: ClusterIP/443 alone permits nothing,
  # the node address on 6443 alone permits the ClusterIP dial. So rule_api_endpoints is the half
  # that actually grants API access here, and rule_api_cluster_ip is the half that would on a
  # dataplane matching pre-DNAT -- inert, but never widening, and not safe to drop.
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

  # distinct() so a call site that names the same CIDR twice renders one peer, not two.
  cidr_peers = distinct(var.to_cidrs)

  rule_cidrs = length(local.cidr_peers) > 0 ? {
    ports = []
    to    = [for cidr in local.cidr_peers : { ip_block = { cidr = cidr } }]
  } : null

  # --- render order: frozen, this list IS the rendered spec -------------------------------
  # self (unless allow_namespace = false) -> DNS -> to_namespaces -> API (ClusterIP, then the
  # control-plane addresses) -> cluster -> internet -> to_cidrs.
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
