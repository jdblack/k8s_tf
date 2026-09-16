# One call = one NetworkPolicy, egress only, for the peers the base builder cannot express:
# a namespace *and* the pods in it, on *named* ports. Same contract as `egress` otherwise --
# callers state intent, this decides selectors and rule order -- and the two are meant to be
# used together on one pod, since netpols only union.
#
# What it does NOT do, on purpose: no `allow_internet`, no `allow_k8s_api`, no `allow_cluster`,
# no `to_cidrs`. Those are the base builder's curated knobs; this one is for a named peer. A
# CIDR handed to either builder is dead for any in-cluster destination anyway (egress is
# evaluated POST-DNAT -- see .clinedocs/calico-netpols.md).
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
