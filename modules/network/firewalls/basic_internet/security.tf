locals {
  egresses = concat(
    var.allow_to_services ? [local.egress.to_kube_network] : [],
    var.allow_to_ns ? [local.egress.to_namespace] : [],
    var.allow_dns ? [local.egress.to_dns] : [],
    var.allow_to_k8sapi ? [local.egress.to_k8s_api] : [],
    var.allow_internet ? [local.egress.to_internet] : [],
    [for cidr in var.egress_allow_ip_blocks : {
      peers = [{ ip_block = { cidr = cidr } }]
    }],
  )
}


module "policy" {
  source       = "../policy"
  name         = var.policy_name
  namespace    = var.namespace
  policy_types = ["Egress"]
  egress_rules = local.egresses
}
