locals {
  # `one()` is null when data.tf disabled the read (caller-supplied IPs) and
  # try() turns that into an empty list, which is the correct peer set.
  api_peer_ips = var.api_peer_ips != null ? var.api_peer_ips : flatten([
    for s in try(one(data.kubernetes_endpoints_v1.kubernetes).subset, []) : [
      for a in s.address : a.ip
    ]
  ])

  # DNS plus the API server, and deliberately nothing else: this is a *targeted*
  # supplement to a namespace-wide basic_internet policy. NetPols union, so pods
  # matching var.pod_selector get both; other pods only the namespace-wide one.
  egresses = concat(
    var.allow_dns ? [local.egress.to_dns] : [],
    [local.egress.to_k8s_api],
  )

  egress = {
    to_dns = {
      peers = [
        {
          namespace_selector = { "kubernetes.io/metadata.name" = var.system_namespace }
          pod_selector       = { "k8s-app" = "kube-dns" }
        }
      ]
      ports = [
        { protocol = "UDP", port = 53 },
        # CoreDNS answers over TCP when UDP responses are truncated.
        { protocol = "TCP", port = 53 },
      ]
    }

    to_k8s_api = {
      peers = concat(
        [{ ip_block = { cidr = format("%s/32", cidrhost(var.service_cidr, 1)) } }],
        # this rule sees destination IPs post-DNAT, i.e. the node IPs
        [
          for ip in local.api_peer_ips : {
            ip_block = { cidr = format("%s/32", ip) }
          }
        ],
      )
      ports = [
        { protocol = "TCP", port = 6443 }
      ]
    }
  }
}

module "policy" {
  source       = "../policy"
  name         = var.policy_name
  namespace    = var.namespace
  pod_selector = var.pod_selector
  policy_types = ["Egress"]
  egress_rules = local.egresses
}
