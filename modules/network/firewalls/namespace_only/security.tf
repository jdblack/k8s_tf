locals {
  egresses = concat(
    [local.to_namespace],
    var.allow_dns ? [local.to_dns] : [],
    var.allow_internet ? [local.to_internet] : [],
  )
  ingresses = concat(
    [ local.from_namespace ],
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
      policyTypes = [ "Egress", "Ingress" ]
      egress = local.egresses
      ingress = local.ingresses
    }
  })
}

