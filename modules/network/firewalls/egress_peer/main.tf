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

        dynamic "to" {
          for_each = egress.value.to

          content {
            dynamic "namespace_selector" {
              for_each = try(to.value.namespace, null) != null ? [to.value.namespace] : []

              content {
                match_labels = {
                  "kubernetes.io/metadata.name" = namespace_selector.value
                }
              }
            }

            dynamic "pod_selector" {
              for_each = try(to.value.pod_selector, null) != null || length(try(to.value.pod_selector_expressions, [])) > 0 ? [to.value] : []

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
          }
        }
      }
    }
  }
}
