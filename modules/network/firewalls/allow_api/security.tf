locals {
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
        # the apiserver's actual endpoint IPs (control-plane nodes), post-DNAT.
        # NOTE: this data source has no `count`, so it is a single object, NOT a
        # list -- do not wrap it in one() (one(<object>) throws and try() would
        # swallow the whole lookup, dropping these rules).
        flatten([
          for s in try(data.kubernetes_endpoints_v1.kubernetes.subset, []) : [
            for a in s.address : {
              ip_block = { cidr = format("%s/32", a.ip) }
            }
          ]
        ]),
      )
      ports = [
        { protocol = "TCP", port = 6443 }
      ]
    }
  }
}

# Rendering is delegated to the shared `policy` module (basic_internet explains
# why the typed resource matters). The `moved` block migrates the inline resource
# into the submodule with no destroy/create.
module "policy" {
  source       = "../policy"
  name         = var.policy_name
  namespace    = var.namespace
  pod_selector = var.pod_selector
  policy_types = ["Egress"]
  egress_rules = local.egresses
}

moved {
  from = kubernetes_network_policy_v1.limit_egresses
  to   = module.policy.kubernetes_network_policy_v1.this
}
