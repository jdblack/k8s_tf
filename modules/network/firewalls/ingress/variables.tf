variable "namespace" {
  type        = string
  description = "Namespace the policy lives in and governs."
}

variable "pod_selector" {
  type        = map(string)
  description = "Labels on the governed pods -- the destination, not the caller. Empty (default) = every pod in the namespace."
  default     = {}
}

variable "pod_selector_expressions" {
  type = list(object({
    key      = string
    operator = string
    values   = optional(list(string))
  }))
  description = "Extra ANDed label rules: `[{ key, operator, values }]`, operator In/NotIn/Exists/DoesNotExist; NotIn also matches a missing key."
  default     = []
}

variable "name" {
  type        = string
  description = "metadata.name. Set this or name_prefix, not both -- name wins."
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "Prefix for a generated name, `<name_prefix>-<8 hex>`. Default namespace-ingress."
  default     = null
}

variable "allow_namespace" {
  type        = bool
  description = "Allow ingress from this namespace's own pods, any port. Default true: nearly every app needs it."
  default     = true
}

variable "from_namespaces" {
  type        = list(string)
  description = "Other namespaces whose pods may connect in, any port. Duplicates collapse. Name pods or ports with from_peers instead."
  default     = []
}

variable "from_peers" {
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
  description = "Explicit callers, one rule each; ports are the destination pod's ports (DNAT precedes policy), omitting pod_selector or ports widens that rule."
  default     = []
}

variable "allow_nodes" {
  type        = bool
  description = "Allow node IPs and Calico IPIP tunnels, any port; off makes governed pods go NotReady."
  default     = true
}

variable "allow_cluster" {
  type        = bool
  description = "Allow the pod CIDR, any port; prefer from_namespaces, since a source is never a ClusterIP."
  default     = false
}

variable "allow_internet" {
  type        = bool
  description = "Allow public source addresses: 0.0.0.0/0 minus RFC1918 and link-local. For a WAN-forwarded LoadBalancer; LAN clients need from_cidrs or allow_nodes."
  default     = false
}

variable "from_cidrs" {
  type        = list(string)
  description = "Extra source CIDRs to allow, one ipBlock each: the LAN, a NAS, an off-cluster host."
  default     = []
}
