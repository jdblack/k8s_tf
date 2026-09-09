# Ingress firewall: pods in this namespace accept connections only from the
# listed namespaces. Everything else (including LAN/host sources) is dropped.
#
# This is the "namespace_only" posture with a guest list: same-namespace-only
# is just allowed_ingress_namespaces = [var.namespace]. It is the natural
# profile for anything served through the shared kube-network gateways, which
# must appear in the list (e.g. ["kube-storage", "kube-network"] for
# gateway-fronted storage) plus "monitoring" if Prometheus scrapes it.
#
# Rendered with the typed kubernetes_network_policy_v1 resource so live drift
# is visible to `tofu plan` (see basic_internet/security.tf for the rationale).
resource "kubernetes_network_policy_v1" "limit_ingresses" {
  metadata {
    name      = var.policy_name
    namespace = var.namespace
  }

  spec {
    # Empty podSelector = the whole namespace.
    pod_selector {}

    policy_types = ["Ingress"]

    # One ingress rule whose peers are the allowed namespaces. An ingress rule
    # with NO `from` peers would mean "allow from anywhere", so only emit the
    # rule when the list is non-empty; an empty list therefore denies all
    # ingress (nothing to allow, default-deny applies).
    dynamic "ingress" {
      for_each = length(var.allowed_ingress_namespaces) > 0 ? [1] : []

      content {
        dynamic "from" {
          for_each = toset(var.allowed_ingress_namespaces)

          content {
            namespace_selector {
              match_labels = {
                "kubernetes.io/metadata.name" = from.value
              }
            }
          }
        }
      }
    }
  }
}
