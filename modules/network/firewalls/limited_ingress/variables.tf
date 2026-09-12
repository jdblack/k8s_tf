variable "namespace" { type = string }

# The NetworkPolicy name within the namespace. NetworkPolicies are namespaced,
# so this only needs to differ when multiple firewall modules target the same
# namespace (e.g. an ingress policy plus an egress policy could share a
# namespace only if one of them renames).
variable "policy_name" { default = "namespace-firewall" }

# Which pods IN THIS NAMESPACE the policy applies to. Empty (default) =
# `podSelector: {}` = the whole namespace (the normal whole-namespace lockdown).
# Set it to run this module a SECOND time as a pod-scoped supplement: keep the
# namespace-wide call's guest list tight, then add a call with pod_selector =
# the target's labels and the extra namespace in allowed_ingress_namespaces, so
# only that target becomes reachable from it.
#
# NOTE: this scopes the DESTINATION. A peer's own podSelector would select the
# SOURCE pods in the guest namespace, not which pods here are reachable -- so
# destination scoping has to be its own policy (NetworkPolicies combine as a
# union).
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods this policy applies to (empty = whole namespace)."
  default     = {}
}

# Namespaces allowed to reach ANY pod in var.namespace. Each entry becomes an
# ingress peer (namespaceSelector match), i.e. any pod in that namespace.
# Everything outside the list is denied. The target namespace's own pods are
# NOT automatically allowed -- include it in the list when self-talk is needed.
variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "Namespaces whose pods may initiate connections into this namespace."
}

# Non-pod source ranges allowed to reach ANY pod in var.namespace, in addition
# to allowed_ingress_namespaces. Each entry renders as an ipBlock peer in the
# same ingress rule.
#
# Use this for services reached directly from OUTSIDE the cluster via a
# LoadBalancer/NodePort: the client's source IP is not a pod in any namespace,
# so no namespaceSelector will ever match it.
#
#   - cidr   : the allowed range (e.g. the LAN, or 0.0.0.0/0 for the internet).
#   - except : optional sub-ranges subtracted from `cidr` (must be inside it).
#
# `0.0.0.0/0` with `except = [<cluster pod/service CIDRs>]` allows every
# EXTERNAL source (LAN + internet + node IPs) while still denying every pod in
# the cluster. That is the right posture for a namespace whose LoadBalancers
# are reached from outside the cluster (where the source is a LAN client or a
# public peer, never a pod).
#
# Empty list (default) keeps the namespace-only behaviour.
variable "allowed_ingress_cidrs" {
  type = list(object({
    cidr   = string
    except = optional(list(string), [])
  }))
  description = "Non-pod source ranges allowed to reach the namespace, each with optional excluded sub-ranges."
  default     = []
}
