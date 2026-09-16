# One call = one NetworkPolicy, egress only. Ingress is deliberately not a knob: a policy that types
# Ingress is deny-all-inbound for the pods it selects, so there is no safe default to hand out.
# Exists only to make the default naming unique; an explicit `name` needs no suffix.
resource "random_id" "suffix" {
  count       = var.name == null ? 1 : 0
  byte_length = 4
}

resource "kubernetes_network_policy_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "OpenTofu"
    }
  }

  spec {
    # Empty match_labels renders `podSelector: {}` = every pod in the namespace.
    pod_selector {
      match_labels = var.pod_selector
    }

    policy_types = ["Egress"]

    dynamic "egress" {
      for_each = local.egress

      content {
        dynamic "ports" {
          for_each = egress.value.ports

          content {
            port     = ports.value.port
            protocol = ports.value.protocol
          }
        }

        # One `to` entry may carry two selector kinds: the DNS rule needs namespaceSelector AND
        # podSelector, which is an AND inside a single peer.
        dynamic "to" {
          for_each = egress.value.to

          content {
            dynamic "namespace_selector" {
              for_each = try(to.value.namespace, null) != null ? [to.value.namespace] : []

              content {
                # The implicit per-namespace label, so callers pass names not selectors.
                match_labels = {
                  "kubernetes.io/metadata.name" = namespace_selector.value
                }
              }
            }

            dynamic "pod_selector" {
              for_each = try(to.value.pod_selector, null) != null ? [to.value.pod_selector] : []

              content {
                match_labels = pod_selector.value
              }
            }

            dynamic "ip_block" {
              for_each = try(to.value.ip_block, null) != null ? [to.value.ip_block] : []

              content {
                cidr   = ip_block.value.cidr
                except = try(ip_block.value.except, null)
              }
            }
          }
        }
      }
    }
  }
}
