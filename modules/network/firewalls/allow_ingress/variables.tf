variable "namespace" { type = string }

# The NetworkPolicy name within the namespace. NetworkPolicies are namespaced,
# so this only needs to differ when multiple firewall modules target the same
# namespace (e.g. an ingress policy plus an egress policy could share a
# namespace only if one of them renames).
variable "policy_name" { default = "namespace-firewall" }

# Namespaces allowed to reach ANY pod in var.namespace. Each entry becomes an
# ingress peer (namespaceSelector match), i.e. any pod in that namespace.
# Everything outside the list is denied. The target namespace's own pods are
# NOT automatically allowed -- include it in the list when self-talk is needed.
variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "Namespaces whose pods may initiate connections into this namespace."
}
