variable namespace { type = string } 
variable allow_internet { default = true }
variable allow_dns { default = true }
variable allow_to_ns { default = true }
variable allow_to_services { default = true }

locals {
  egresses = concat(
    var.allow_to_services ? [ local.egress.to_kube_network ] : [],
    var.allow_to_ns ? [local.egress.to_namespace] : [],
    var.allow_dns ? [local.egress.to_dns] : [],
    var.allow_internet ? [local.egress.to_internet] : [],
  )

  egress = {
    to_internet = {
      to = [
        {
          ipBlock = {
            cidr = "0.0.0.0/0"
            except = [ "10.0.0.0/8" ]
          }
        }
      ]
    }

    to_kube_network = {
      to = [
        {
          namespaceSelector = {
            matchlabels = { 
              "kubernetes.io/metadata.name" = "kube-network"
            }
          }

          podSelector = {}

        }
      ]
    }

    to_namespace = {
      to = [
        {
          namespaceSelector = {
            matchLabels = { "kubernetes.io/metadata.name" = var.namespace }
          }
          podSelector = {}
        }
      ]
    }


    to_dns = {
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
      egress = local.egresses
    }
  })
}

