# One rendered kubernetes_network_policy_v1 from explicit rule lists.
#
# Typed resource (not kubectl_manifest) so `tofu plan` diffs against live state
# and flags out-of-band drift -- see ../../README.md (a kubectl_manifest-backed
# NetPol was once edited behind tofu's back and silently became allow-all).
#
# ingress_rules -> spec.ingress[].from[]   (source peers)
# egress_rules  -> spec.egress[].to[]      (destination peers)
# Each peer may carry ip_block, namespace_selector and/or pod_selector; a peer
# with only namespace_selector (no pod_selector) means "any pod in that ns".
resource "kubernetes_network_policy_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    # Empty map = the whole namespace.
    pod_selector {
      match_labels = length(var.pod_selector) > 0 ? var.pod_selector : null
    }

    policy_types = var.policy_types

    dynamic "ingress" {
      for_each = var.ingress_rules

      content {
        dynamic "from" {
          for_each = try(ingress.value.peers, [])

          content {
            dynamic "ip_block" {
              for_each = lookup(from.value, "ip_block", null) != null ? [from.value.ip_block] : []
              content {
                cidr = ip_block.value.cidr
                # Only set `except` when present; null omits it so the API
                # doesn't normalize an empty list into a perpetual diff.
                except = try(ip_block.value.except, null)
              }
            }

            dynamic "namespace_selector" {
              for_each = lookup(from.value, "namespace_selector", null) != null ? [from.value.namespace_selector] : []
              content {
                match_labels = namespace_selector.value
              }
            }

            # An empty podSelector alongside a namespaceSelector = "all pods in
            # that namespace" -- omit it rather than emitting pod_selector {}.
            dynamic "pod_selector" {
              for_each = lookup(from.value, "pod_selector", null) != null && length(from.value.pod_selector) > 0 ? [from.value.pod_selector] : []
              content {
                match_labels = pod_selector.value
              }
            }
          }
        }

        dynamic "ports" {
          for_each = try(ingress.value.ports, [])
          content {
            protocol = ports.value.protocol
            port     = tostring(ports.value.port)
          }
        }
      }
    }

    dynamic "egress" {
      for_each = var.egress_rules

      content {
        dynamic "to" {
          for_each = try(egress.value.peers, [])

          content {
            dynamic "ip_block" {
              for_each = lookup(to.value, "ip_block", null) != null ? [to.value.ip_block] : []
              content {
                cidr   = ip_block.value.cidr
                except = try(ip_block.value.except, null)
              }
            }

            dynamic "namespace_selector" {
              for_each = lookup(to.value, "namespace_selector", null) != null ? [to.value.namespace_selector] : []
              content {
                match_labels = namespace_selector.value
              }
            }

            dynamic "pod_selector" {
              for_each = lookup(to.value, "pod_selector", null) != null && length(to.value.pod_selector) > 0 ? [to.value.pod_selector] : []
              content {
                match_labels = pod_selector.value
              }
            }
          }
        }

        dynamic "ports" {
          for_each = try(egress.value.ports, [])
          content {
            protocol = ports.value.protocol
            port     = tostring(ports.value.port)
          }
        }
      }
    }
  }
}