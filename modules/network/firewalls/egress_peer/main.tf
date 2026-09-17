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

            # A peer renders a podSelector when it names labels OR expressions; both land inside this one
            # `to` entry beside the namespaceSelector, so they AND.
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
