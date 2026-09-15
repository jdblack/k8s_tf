variable "namespace" { type = string }

# Only has to differ when several firewall modules share a namespace.
variable "policy_name" { default = "namespace-firewall" }

# Which pods HERE the policy applies to. Empty = the whole namespace. Destination
# scoping needs its own policy: a peer's podSelector would select SOURCE pods in the
# guest namespace, and NetPols union.
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods this policy applies to (empty = whole namespace)."
  default     = {}
}

# Each becomes a namespaceSelector peer (any pod in it). The namespace's own pods are
# NOT implied.
variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "Namespaces whose pods may initiate connections into this namespace."
}

# Non-pod sources, for anything reached from OUTSIDE the cluster: no namespaceSelector
# can match those clients. `0.0.0.0/0` with `except = [<cluster CIDRs>]` allows every
# external source while denying every pod. Empty = namespace-only.
variable "allowed_ingress_cidrs" {
  type = list(object({
    cidr   = string
    except = optional(list(string), [])
  }))
  description = "Non-pod source ranges allowed to reach the namespace, each with optional excluded sub-ranges."
  default     = []
}
