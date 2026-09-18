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
  description = "Extra label rules for the governed pods, ANDed with pod_selector and with each other: `[{ key, operator, values }]`, operator In/NotIn/Exists/DoesNotExist (values omitted for the last two). NotIn also matches a pod that has no such key at all, so `[{ key = \"app\", operator = \"NotIn\", values = [\"plex\"] }]` leaves out exactly the pods labeled app=plex (measured 2026-09-17). Expressions AND, never OR."
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
  description = "Explicit callers: `{ namespace, pod_selector, pod_selector_expressions, ports = [{port, protocol}] }`, one caller per rule, in list order. Ports are the destination pod's ports, not the Service's -- kube-proxy DNATs before ingress is evaluated. A null pod_selector means every pod in that namespace and empty ports means every port; both selectors in one caller AND."
  default     = []
}

variable "allow_nodes" {
  type        = bool
  description = "Allow each node's InternalIP and Calico IPIP tunnel address, any port. Default true: kubelet probes arrive from the node's InternalIP and cross-node apiserver calls from the sending node's tunnel address, so turning it off makes governed pods go NotReady. A failed node read drops the rule, never widens it."
  default     = true
}

variable "allow_cluster" {
  type        = bool
  description = "Allow the pod CIDR, any port: any pod in the cluster. Prefer from_namespaces. No service-CIDR peer, because a source is never a ClusterIP (DNAT rewrites the destination, not the source)."
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
