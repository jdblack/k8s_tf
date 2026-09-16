variable "namespace" {
  type        = string
  description = "Namespace whose pods this policy governs -- and where the policy object lives."
}

variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the governed pods. Empty (default) = every pod in the namespace."
  default     = {}
}

variable "name" {
  type        = string
  description = "metadata.name of the NetworkPolicy. Set this or name_prefix, not both -- name wins. Null (the default) = name_prefix plus a generated suffix."
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "Prefix for a generated metadata.name, `<name_prefix>-<8 hex>`. Ignored when name is set. Defaults to peer-egress, so a call that omits both is still uniquely named."
  default     = null
}

variable "allow_namespace" {
  type        = bool
  description = "Allow egress to THIS namespace's own pods -- the self rule, rendered first. On by default for the same reason as the base builder: losing intra-namespace traffic looks like a broken application rather than like policy. Redundant, never harmful, when a base `egress` call already covers the pod -- netpols union."
  default     = true
}

# `to_*` takes an explicit peer list, like the base builder; this is the one that can also say
# *which pods* and *which ports*, which a to_namespaces peer cannot.
variable "to_peers" {
  type = list(object({
    namespace    = string
    pod_selector = optional(map(string))
    ports = optional(list(object({
      port     = number
      protocol = optional(string, "TCP")
    })), [])
  }))
  description = "Explicit cross-namespace peers: `{ namespace, pod_selector = <labels or null>, ports = [{port, protocol}] }`. One peer per rule, rendered in list order, so each carries its own ports. A null/omitted `pod_selector` means every pod in that namespace -- prefer naming the pods, that is the point of this builder; an empty `ports` means every port."
  default     = []
}
