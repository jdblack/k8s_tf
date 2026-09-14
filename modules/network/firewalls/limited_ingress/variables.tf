variable "namespace" { type = string }

# NetworkPolicies are namespaced, so this only has to differ when several
# firewall modules target the same namespace.
variable "policy_name" { default = "namespace-firewall" }

# Which pods HERE the policy applies to. Empty (default) = the whole namespace.
# Set it to run this module a SECOND time as a pod-scoped supplement: keep the
# namespace-wide call's guest list tight, then add a call with pod_selector =
# the target's labels and the extra namespace in allowed_ingress_namespaces.
#
# This scopes the DESTINATION: a peer's podSelector would select SOURCE pods in
# the guest namespace. NetworkPolicies union, so destination scoping has to be
# its own policy.
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods this policy applies to (empty = whole namespace)."
  default     = {}
}

# Namespaces whose pods may reach this namespace; everything else is denied.
# Each entry becomes a namespaceSelector peer (any pod in that namespace). The
# namespace's own pods are NOT implied -- list it when self-talk is needed.
variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "Namespaces whose pods may initiate connections into this namespace."
}

# Non-pod source ranges, in addition to allowed_ingress_namespaces. Use these
# for anything reached from OUTSIDE the cluster via LoadBalancer/NodePort: the
# client is not a pod, so no namespaceSelector will ever match it.
#
#   - cidr   : the allowed range (LAN, or 0.0.0.0/0).
#   - except : optional sub-ranges subtracted from `cidr`.
#
# `0.0.0.0/0` with `except = [<cluster pod/service CIDRs>]` = every external
# source allowed while every cluster pod stays denied.
#
# Empty (default) = namespace-only.
variable "allowed_ingress_cidrs" {
  type = list(object({
    cidr   = string
    except = optional(list(string), [])
  }))
  description = "Non-pod source ranges allowed to reach the namespace, each with optional excluded sub-ranges."
  default     = []
}
