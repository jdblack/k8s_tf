variable "namespace" { type = string }

# NetworkPolicies are namespaced, so this only has to differ when several
# firewall modules target the same namespace.
variable "policy_name" { default = "namespace-firewall" }

# Which pods HERE the policy applies to. Empty (default) = the whole namespace.
# This scopes the DESTINATION: a peer's podSelector would select SOURCE pods in
# the guest namespace, and NetPols union, so destination scoping has to be its
# own policy.
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods this policy applies to (empty = whole namespace)."
  default     = {}
}

# Namespaces whose pods may reach this namespace; each becomes a namespaceSelector
# peer (any pod in it). The namespace's own pods are NOT implied.
variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "Namespaces whose pods may initiate connections into this namespace."
}

# Non-pod source ranges, for anything reached from OUTSIDE the cluster via
# LoadBalancer/NodePort -- no namespaceSelector can ever match those clients.
# `0.0.0.0/0` with `except = [<cluster pod/service CIDRs>]` allows every external
# source while denying every cluster pod. Empty (default) = namespace-only.
variable "allowed_ingress_cidrs" {
  type = list(object({
    cidr   = string
    except = optional(list(string), [])
  }))
  description = "Non-pod source ranges allowed to reach the namespace, each with optional excluded sub-ranges."
  default     = []
}
