

locals {
  allow_internet = {
    to = [
      {
        ipBlock = {
          cidr = "0.0.0.0/0"
          except = [ "10.244.0.0/16" ]
        }
      }
    ]
  }

  allow_namespace = {
    to = [
      {
        namespaceSelector = {
          matchLabels = { name = var.namespace }
        }
      }
    ]
  }

  allow_dns = {
    to = [
      {
        namespaceSelector = {
          matchLabels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        podSelector = {
          matchLabels = { "k8s-app" = "kube-dns" }
        }
      }
    ]
    ports = [
      {
        protocol = "UDP"
        port = 53
      }
    ]
  }


}



resource kubectl_manifest monitor {
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
      egress = [
        local.allow_internet,
        local.allow_namespace,
        local.allow_dns
      ]
    }
  })
}

