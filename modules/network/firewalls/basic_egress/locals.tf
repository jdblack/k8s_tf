locals {

  # kube-dns lives here. Not a knob: nothing in a namespace resolves without it.
  system_namespace = "kube-system"

  # kube-proxy SNATs nodePort/remote-backend traffic to a node IP, so the node and LAN
  # ranges must be excluded or a workload could trampoline into the LAN. Not a knob either:
  # a namespace that needs a LAN address asks for it by name via `allow_cidrs`.
  blocked_egress_cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"]

  # `one()` is null when data.tf disabled the read (caller-supplied IPs); try() turns that
  # into an empty list, which is the correct peer set.
  api_peer_ips = var.api_peer_ips != null ? var.api_peer_ips : flatten([
    for s in try(one(data.kubernetes_endpoints_v1.kubernetes).subset, []) : [
      for a in s.address : a.ip
    ]
  ])

  egress = {
    # One rule per namespace, in var order.
    to_namespaces = [
      for ns in var.allow_namespaces : {
        peers = [
          {
            namespace_selector = {
              "kubernetes.io/metadata.name" = ns
            }
          }
        ]
      }
    ]

    to_dns = {
      peers = [
        {
          namespace_selector = {
            "kubernetes.io/metadata.name" = local.system_namespace
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
        # CoreDNS answers over TCP when UDP responses are truncated (large TXT/SRV/any
        # records); without this, occasional lookups fail.
        {
          protocol = "TCP"
          port     = 53
        }
      ]
    }

    to_k8s_api = {
      peers = concat(
        [{ ip_block = { cidr = format("%s/32", cidrhost(var.service_cidr, 1)) } }],
        # this rule sees destination IPs post-DNAT, i.e. the node IPs
        [
          for ip in local.api_peer_ips : {
            ip_block = { cidr = format("%s/32", ip) }
          }
        ],
      )
      ports = [
        {
          protocol = "TCP"
          port     = 6443
        }
      ]
    }

    to_internet = {
      peers = [
        {
          ip_block = {
            cidr   = "0.0.0.0/0"
            except = local.blocked_egress_cidrs
          }
        }
      ]
    }

    # Each carve-out is its own rule, so it wins over the internet rule's `except`.
    to_cidrs = [
      for cidr in var.allow_cidrs : {
        peers = [
          {
            ip_block = {
              cidr = cidr
            }
          }
        ]
      }
    ]
  }

}
