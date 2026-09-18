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
    pod_selector {
      # An empty map and no matchLabels are the same selector to the API; the empty map fails apply (provider bug).
      match_labels = length(var.pod_selector) > 0 ? var.pod_selector : null

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

        dynamic "from" {
          for_each = ingress.value.from

          content {
            dynamic "namespace_selector" {
              for_each = try(from.value.namespace, null) != null ? [from.value.namespace] : []

              content {
                match_labels = {
                  "kubernetes.io/metadata.name" = namespace_selector.value
                }
              }
            }

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
