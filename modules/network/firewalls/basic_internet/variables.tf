variable namespace { type = string } 
variable allow_internet { default = true }
variable allow_dns { default = true }
variable allow_to_ns { default = true }
variable allow_to_services { default = false }

locals {

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

