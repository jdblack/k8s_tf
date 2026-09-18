variable "namespace" {
  type        = string
  description = "Namespace the policy lives in and governs."
}

variable "pod_selector" {
  type        = map(string)
  description = "Labels on the governed pods. Empty (default) = every pod in the namespace."
  default     = {}
}

variable "pod_selector_expressions" {
  type = list(object({
    key      = string
    operator = string
    values   = optional(list(string))
  }))
  description = "Extra label rules for the governed pods, ANDed with pod_selector and with each other: `[{ key, operator, values }]`, operator In/NotIn/Exists/DoesNotExist (values omitted for the last two). NotIn also matches a pod that has no such key at all, so values lists the pods to leave out (measured 2026-09-17). Expressions AND, never OR."
  default     = []
}

variable "name" {
  type        = string
  description = "metadata.name. Set this or name_prefix, not both -- name wins."
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "Prefix for a generated name, `<name_prefix>-<8 hex>`. Default peer-egress."
  default     = null
}

variable "allow_namespace" {
  type        = bool
  description = "Allow egress to this namespace's own pods, any port. Default true. Redundant but harmless next to a base `egress` call, since policies union."
  default     = true
}

variable "to_peers" {
  type = list(object({
    namespace    = string
    pod_selector = optional(map(string))
    pod_selector_expressions = optional(list(object({
      key      = string
      operator = string
      values   = optional(list(string))
    })), [])
    ports = optional(list(object({
      port     = number
      protocol = optional(string, "TCP")
    })), [])
  }))
  description = "Explicit peers: `{ namespace, pod_selector, pod_selector_expressions, ports = [{port, protocol}] }`, one peer per rule, in list order. A null pod_selector means every pod in that namespace and empty ports means every port -- name one or both wherever you can. Both selectors in one peer AND."
  default     = []
}
