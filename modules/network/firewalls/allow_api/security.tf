locals {
  # Two egress rules: DNS (so the pods can resolve kubernetes.default.svc) and
  # the Kubernetes API server itself. There is deliberately NO same-namespace,
  # internet or kube-network rule here -- this policy is a *targeted
  # supplement* to a namespace-wide basic_internet policy that already allows
  # those. Kubernetes NetworkPolicies combine additively (union), so the pods
  # matching var.pod_selector get the union of both policies; every other pod
  # in the namespace only gets the namespace-wide one.
  egresses = concat(
    var.allow_dns ? [local.egress.to_dns] : [],
    [local.egress.to_k8s_api],
  )

  egress = {
    to_dns = {
      to = [
        {
          namespaceSelector = {
            matchLabels = { "kubernetes.io/metadata.name" = var.system_namespace }
          }
          podSelector = {
            matchLabels = { "k8s-app" = "kube-dns" }
          }
        }
      ]
      ports = [
        { protocol = "UDP", port = 53 },
        # CoreDNS also answers over TCP when responses are truncated for UDP.
        { protocol = "TCP", port = 53 },
      ]
    }

    to_k8s_api = {
      to = concat(
        # kubernetes.default.svc ClusterIP
        [{ ipBlock = { cidr = "10.96.0.1/32" } }],
        # the apiserver's actual endpoint IPs (control-plane nodes), post-DNAT.
        # NOTE: this data source has no `count`, so it is a single object, NOT a
        # list -- do not wrap it in one() (one(<object>) throws and try() would
        # silently swallow the whole endpoint lookup, dropping these rules).
        flatten([
          for s in try(data.kubernetes_endpoints_v1.kubernetes.subset, []) : [
            for a in s.address : {
              ipBlock = { cidr = format("%s/32", a.ip) }
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

# Rendered with the typed kubernetes_network_policy_v1 resource (see
# basic_internet/security.tf for why: kubectl_manifest cannot see live drift).
resource "kubernetes_network_policy_v1" "limit_egresses" {
  metadata {
    name      = var.policy_name
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = var.pod_selector
    }

    policy_types = ["Egress"]

    dynamic "egress" {
      for_each = local.egresses

      content {
        dynamic "to" {
          for_each = egress.value.to

          content {
            dynamic "ip_block" {
              for_each = lookup(to.value, "ipBlock", null) != null ? [to.value.ipBlock] : []
              content {
                cidr = ip_block.value.cidr
                # Only set `except` when present; null omits it so the API
                # doesn't normalize an empty list and cause perpetual diffs.
                except = try(ip_block.value.except, null)
              }
            }

            dynamic "namespace_selector" {
              for_each = lookup(to.value, "namespaceSelector", null) != null ? [to.value.namespaceSelector] : []
              content {
                match_labels = namespace_selector.value.matchLabels
              }
            }

            dynamic "pod_selector" {
              for_each = lookup(to.value, "podSelector", null) != null && length(to.value.podSelector) > 0 ? [to.value.podSelector] : []
              content {
                match_labels = pod_selector.value.matchLabels
              }
            }
          }
        }

        dynamic "ports" {
          for_each = lookup(egress.value, "ports", null) != null ? egress.value.ports : []
          content {
            protocol = ports.value.protocol
            port     = tostring(ports.value.port)
          }
        }
      }
    }
  }
}
