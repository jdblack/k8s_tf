variable "direction" {
  type        = string
  description = "`ingress` admits traffic into the governed pods, `egress` admits it out of them."

  validation {
    condition     = contains(["ingress", "egress"], var.direction)
    error_message = "direction must be \"ingress\" or \"egress\"."
  }
}

variable "namespace" {
  type        = string
  description = "Namespace the policy lives in and governs."
}

variable "name" {
  type        = string
  description = "metadata.name."
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
  description = "Extra ANDed label rules for the governed pods: `[{ key, operator, values }]`, operator In/NotIn/Exists/DoesNotExist."
  default     = []
}

variable "peers" {
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
  description = "Explicit peers, one rule each; ports are the governed pod's own ports, since kube-proxy DNATs before policy runs. Omitting pod_selector or ports widens that rule."
  default     = []
}

variable "allow_namespace" {
  type        = bool
  description = "Admit this namespace's own pods, any port. Default true: nearly every app needs it."
  default     = true
}

variable "allow_internet" {
  type        = bool
  description = "Ingress: public source addresses. Egress: 0.0.0.0/0 minus RFC1918 and link-local, so it never reaches the LAN."
  default     = false
}

variable "allow_k8s_api" {
  type        = bool
  default     = false
  description = "Egress only. Allow the API server: TCP/6443 to the control-plane node CIDRs plus TCP/443 to the kubernetes Service ClusterIP. kube-proxy DNATs before policy runs, so the node rule is the one that matches; the ClusterIP rule covers a dataplane matching pre-DNAT. The node rule is widened per api_endpoint_prefix_length."

  validation {
    condition     = !(var.direction == "ingress" && var.allow_k8s_api)
    error_message = "allow_k8s_api only applies to direction = \"egress\"."
  }
}

variable "api_endpoint_prefix_length" {
  type        = number
  default     = 24
  description = "Egress only. Prefix each discovered API server endpoint is widened to for the TCP/6443 rule: a /32 stops matching the moment DHCP moves the control-plane node, a /24 stays valid across any lease change inside the host subnet. Set to 32 to pin exactly, or lower to cover a wider host network."

  validation {
    condition     = var.api_endpoint_prefix_length >= 0 && var.api_endpoint_prefix_length <= 32
    error_message = "api_endpoint_prefix_length must be a CIDR prefix length between 0 and 32."
  }
}
