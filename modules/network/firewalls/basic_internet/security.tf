locals {
  egresses = concat(
    var.allow_to_services ? [local.egress.to_kube_network] : [],
    var.allow_to_ns ? [local.egress.to_namespace] : [],
    var.allow_dns ? [local.egress.to_dns] : [],
    var.allow_to_k8sapi ? [local.egress.to_k8s_api] : [],
    var.allow_internet ? [local.egress.to_internet] : [],
    [for cidr in var.egress_allow_ip_blocks : {
      to = [{ ipBlock = { cidr = cidr } }]
    }],
  )
}


# Rendered with the typed kubernetes_network_policy_v1 resource (not
# kubectl_manifest) so OpenTofu diff-against-state on every plan and flags live
# drift -- a kubectl_manifest-backed NetPol that gets edited out-of-band is
# otherwise invisible to `tofu plan` (this actually happened to the seaweedfs
# policy; its live spec had silently changed to allow-all while tofu reported
# no changes).
resource "kubernetes_network_policy_v1" "limit_egresses" {
  metadata {
    name      = var.policy_name
    namespace = var.namespace
  }

  spec {
    # Empty podSelector = the whole namespace.
    pod_selector {}

    policy_types = ["Egress"]

    # local.egresses is a list of egress rules. Each rule has one or more
    # peers (`to`), each peer being either an ipBlock or a
    # namespaceSelector (+ optional podSelector), plus optional ports.
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

            # An empty podSelector alongside a namespaceSelector means "all pods
            # in that namespace" -- omit it rather than emitting pod_selector {}.
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

