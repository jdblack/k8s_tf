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
      # An empty map is the same selector as no matchLabels, but the empty map fails apply (provider bug).
      match_labels = length(var.pod_selector) > 0 ? var.pod_selector : null
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
