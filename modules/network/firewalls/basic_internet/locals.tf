locals {

  egress = {
    to_internet = {
      to = [
        {
          ipBlock = {
            cidr   = "0.0.0.0/0"
            except = var.blocked_egress_cidrs
          }
        }
      ]
    }

    to_kube_network = {
      to = [
        {
          namespaceSelector = {
            matchLabels = {
              "kubernetes.io/metadata.name" = var.network_namespace
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
              "kubernetes.io/metadata.name" = var.system_namespace
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
          port     = 53
        }
      ]
    }

  }

}
