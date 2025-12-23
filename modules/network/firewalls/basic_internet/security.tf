locals {
  egresses = concat(
    var.allow_to_services ? [ local.egress.to_kube_network ] : [],
    var.allow_to_ns ? [local.egress.to_namespace] : [],
    var.allow_dns ? [local.egress.to_dns] : [],
    var.allow_internet ? [local.egress.to_internet] : [],
  )
}


resource kubectl_manifest limit_egresses {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind = "NetworkPolicy"
    metadata = {
      name = "namespace-firewall"
      namespace = var.namespace
    }
    spec = {
      podSelector = { }
      policyTypes = [ "Egress" ]
      egress = local.egresses
    }
  })
}

