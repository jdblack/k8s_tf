locals {
  # Endpoint IPs of the API server (control-plane nodes), post-DNAT: either
  # handed in by the caller (var.api_peer_ips) or read from the `kubernetes`
  # Endpoints object here. With the data source counted in data.tf, `one()` is
  # null when the read is disabled and try() turns that into an empty list --
  # which is correct, because a caller that passes api_peer_ips gets its peers
  # from the first branch.
  api_peer_ips = var.api_peer_ips != null ? var.api_peer_ips : flatten([
    for s in try(one(data.kubernetes_endpoints_v1.kubernetes).subset, []) : [
      for a in s.address : a.ip
    ]
  ])

  # Two egress rules: DNS (so the pods can resolve kubernetes.default.svc) and the
  # Kubernetes API server itself. Deliberately NO same-namespace, internet or
  # kube-network rule: this policy is a *targeted supplement* to a namespace-wide
  # basic_internet policy that already allows those. NetworkPolicies combine
  # additively, so pods matching var.pod_selector get the union of both; every
  # other pod in the namespace only gets the namespace-wide one.
  egresses = concat(
    var.allow_dns ? [local.egress.to_dns] : [],
    [local.egress.to_k8s_api],
  )

  egress = {
    to_dns = {
      peers = [
        {
          namespace_selector = { "kubernetes.io/metadata.name" = var.system_namespace }
          pod_selector       = { "k8s-app" = "kube-dns" }
        }
      ]
      ports = [
        { protocol = "UDP", port = 53 },
        # CoreDNS also answers over TCP when responses are truncated for UDP.
        { protocol = "TCP", port = 53 },
      ]
    }

    to_k8s_api = {
      peers = concat(
        # kubernetes.default.svc ClusterIP (first host of the service CIDR)
        [{ ip_block = { cidr = format("%s/32", cidrhost(var.service_cidr, 1)) } }],
        # the apiserver's actual endpoint IPs (control-plane nodes), post-DNAT
        [
          for ip in local.api_peer_ips : {
            ip_block = { cidr = format("%s/32", ip) }
          }
        ],
      )
      ports = [
        { protocol = "TCP", port = 6443 }
      ]
    }
  }
}

# Rendering is delegated to the shared `policy` module (basic_internet explains
# why the typed resource matters).
module "policy" {
  source       = "../policy"
  name         = var.policy_name
  namespace    = var.namespace
  pod_selector = var.pod_selector
  policy_types = ["Egress"]
  egress_rules = local.egresses
}
