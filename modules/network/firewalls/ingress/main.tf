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
    # Empty match_labels renders `podSelector: {}` = every pod in the namespace. Expressions are added
    # only when given, so a labels-only call renders exactly what it always did.
    pod_selector {
      match_labels = var.pod_selector

      dynamic "match_expressions" {
        for_each = var.pod_selector_expressions

        content {
          key      = match_expressions.value.key
          operator = match_expressions.value.operator
          values   = try(match_expressions.value.values, null)
        }
      }
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

            # A peer renders a podSelector when it names labels OR expressions; both land inside this one
            # `from` entry beside the namespaceSelector, so they AND.
            dynamic "pod_selector" {
              for_each = try(from.value.pod_selector, null) != null || length(try(from.value.pod_selector_expressions, [])) > 0 ? [from.value] : []

              content {
                match_labels = try(pod_selector.value.pod_selector, null)

                dynamic "match_expressions" {
                  for_each = try(pod_selector.value.pod_selector_expressions, [])

                  content {
                    key      = match_expressions.value.key
                    operator = match_expressions.value.operator
                    values   = try(match_expressions.value.values, null)
                  }
                }
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
