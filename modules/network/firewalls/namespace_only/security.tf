locals {
  ingresses = [
    {
      namespaceSelector = {
        matchLabels = { "kubernetes.io/metadata.name" = var.namespace }
      }
      podSelector = {}
    }
  ]
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
      policyTypes = [ "Ingress" ]
      ingress = local.ingresses
    }
  })
}

