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

    to_k8s_api = {
      to = concat(
        # kubernetes.default.svc ClusterIP
        [{ ipBlock = { cidr = "10.96.0.1/32" } }],
        # the apiserver's actual endpoint IPs (control-plane nodes), post-DNAT
        flatten([
          for s in try(one(data.kubernetes_endpoints_v1.kubernetes).subset, []) : [
            for a in s.address : {
              ipBlock = { cidr = format("%s/32", a.ip) }
            }
          ]
        ]),
      )
      ports = [
        {
          protocol = "TCP"
          port     = 6443
        }
      ]
    }

  }

}
