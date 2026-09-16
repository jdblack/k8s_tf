# One call = one NetworkPolicy, egress only, for the peers the base builder cannot express: a namespace
# *and* the pods in it, on *named* ports. No `allow_internet`/`allow_k8s_api`/`allow_cluster`/`to_cidrs`
# on purpose -- and a CIDR would be dead for an in-cluster destination anyway (egress is POST-DNAT).
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
          }
        }
      }
    }
  }
}
