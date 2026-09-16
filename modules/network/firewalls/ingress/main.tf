# One call = one NetworkPolicy, ingress only. Nothing is implicit beyond the two floors (own namespace,
# the node addresses): a call that names no guest renders a bare Ingress policy, i.e. deny-all-inbound.
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

    policy_types = ["Ingress"]

    dynamic "ingress" {
      for_each = local.ingress

      content {
        dynamic "ports" {
          for_each = ingress.value.ports

          content {
            port     = ports.value.port
            protocol = ports.value.protocol
          }
        }

        # One `from` entry may carry two selector kinds: the peer builder needs namespaceSelector AND
        # podSelector, which is an AND inside a single peer.
        dynamic "from" {
          for_each = ingress.value.from

          content {
            dynamic "namespace_selector" {
              for_each = try(from.value.namespace, null) != null ? [from.value.namespace] : []

              content {
                # The implicit per-namespace label, so callers pass names not selectors.
                match_labels = {
                  "kubernetes.io/metadata.name" = namespace_selector.value
                }
              }
            }

            dynamic "pod_selector" {
              for_each = try(from.value.pod_selector, null) != null ? [from.value.pod_selector] : []

              content {
                match_labels = pod_selector.value
              }
            }

            dynamic "ip_block" {
              for_each = try(from.value.ip_block, null) != null ? [from.value.ip_block] : []

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
