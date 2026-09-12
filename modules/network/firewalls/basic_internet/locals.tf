locals {

  egress = {
    to_internet = {
      peers = [
        {
          ip_block = {
            cidr   = "0.0.0.0/0"
            except = var.blocked_egress_cidrs
          }
        }
      ]
    }

    to_kube_network = {
      peers = [
        {
          namespace_selector = {
            "kubernetes.io/metadata.name" = var.network_namespace
          }
        }
      ]
    }

    to_namespace = {
      peers = [
        {
          namespace_selector = {
            "kubernetes.io/metadata.name" = var.namespace
          }
        }
      ]
    }


    to_dns = {
      peers = [
        {
          namespace_selector = {
            "kubernetes.io/metadata.name" = var.system_namespace
          }
          pod_selector = {
            "k8s-app" = "kube-dns"
          }
        }
      ]
      ports = [
        {
          protocol = "UDP"
          port     = 53
        },
        # CoreDNS also answers over TCP when responses are truncated for UDP
        # (large TXT/SRV/any records). Allow it or occasional DNS lookups fail
        # once a namespace is put behind this firewall.
        {
          protocol = "TCP"
          port     = 53
        }
      ]
    }

    to_k8s_api = {
      peers = concat(
        # kubernetes.default.svc ClusterIP (first host of the service CIDR)
        [{ ip_block = { cidr = format("%s/32", cidrhost(var.service_cidr, 1)) } }],
        # the apiserver's actual endpoint IPs (control-plane nodes), post-DNAT
        flatten([
          for s in try(one(data.kubernetes_endpoints_v1.kubernetes).subset, []) : [
            for a in s.address : {
              ip_block = { cidr = format("%s/32", a.ip) }
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
