# One call = one NetworkPolicy, egress only. Ingress is deliberately not a knob here: a policy
# that types Ingress is deny-all-inbound for the pods it selects, so each app module writes its
# own when it needs one -- there is no safe default to hand out.
resource "kubernetes_network_policy_v1" "this" {
  metadata {
    name      = var.policy_name
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

        # A `to` entry may carry more than one selector kind on purpose: the DNS rule needs
        # namespaceSelector AND podSelector, which is an AND in a single peer.
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
