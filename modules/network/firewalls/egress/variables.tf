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
  description = "Extra label rules for the governed pods, ANDed with pod_selector and with each other: `[{ key, operator, values }]`, operator In/NotIn/Exists/DoesNotExist (values omitted for the last two). Expressions AND, never OR."
  default     = []
}

variable "name" {
  type        = string
  description = "metadata.name. Set this or name_prefix, not both -- name wins."
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "Prefix for a generated name, `<name_prefix>-<8 hex>`. Default namespace-egress."
  default     = null
}

variable "allow_namespace" {
  type        = bool
  description = "Allow egress to this namespace's own pods, any port. Default true: nearly every app needs it."
  default     = true
}

variable "to_namespaces" {
  type        = list(string)
  description = "Other namespaces whose pods may be reached, any port. Duplicates collapse."
  default     = []
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

variable "allow_k8s_api" {
  type        = bool
  description = "Allow the API server: TCP/6443 to the control-plane node IPs plus TCP/443 to the kubernetes Service ClusterIP. kube-proxy DNATs before policy runs, so the node rule is the one that matches; the ClusterIP rule covers a dataplane matching pre-DNAT."
  default     = false
}

variable "allow_cluster" {
  type        = bool
  description = "Allow the pod CIDR and the service CIDR, any port. Prefer to_namespaces."
  default     = false
}

variable "allow_internet" {
  type        = bool
  description = "Allow 0.0.0.0/0 minus RFC1918 and link-local. Never reaches the LAN."
  default     = false
}

variable "to_cidrs" {
  type        = list(string)
  description = "Extra CIDRs to allow, one ipBlock each: a NAS, an off-cluster host, the LAN."
  default     = []
}
