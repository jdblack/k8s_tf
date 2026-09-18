variable "namespace" {
  type        = string
  description = "Namespace whose pods this policy governs -- and where the policy object lives."
}

variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the governed pods -- the DESTINATION, not the guest. Empty (default) = every pod in the namespace. A guest's own labels go in from_peers, never here."
  default     = {}
}

variable "pod_selector_expressions" {
  type = list(object({
    key      = string
    operator = string
    values   = optional(list(string))
  }))
  description = "`matchExpressions` for the governed pods, ANDed with pod_selector and with each other: `[{ key, operator, values }]`, operator one of In/NotIn/Exists/DoesNotExist (values omitted for the last two). `[{ key = \"app\", operator = \"NotIn\", values = [\"plex\"] }]` is how a curtain excludes a pod from itself. `NotIn` also matches a pod that does not carry `key` at all (measured 2026-09-17), which makes one `NotIn` the right shape for a namespace-wide curtain (label-less pods land inside it) and an `In` the wrong shape for a floor (a pod without the key stays default-allow). There is no OR inside one policy: expressions AND, so a second key decides which pods the selector covers at all rather than adding a second exclusion."
  default     = []
}

variable "name" {
  type        = string
  description = "metadata.name of the NetworkPolicy. Set this or name_prefix, not both -- name wins. Null (the default) = name_prefix plus a generated suffix."
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "Prefix for a generated metadata.name, `<name_prefix>-<8 hex>`. Ignored when name is set. Defaults to namespace-ingress, so a call that omits both is still uniquely named."
  default     = null
}

variable "allow_namespace" {
  type        = bool
  description = "Allow ingress from THIS namespace's own pods -- the self rule, rendered first. On by default for the same reason the egress module keeps its own namespace: losing intra-namespace traffic looks like a broken application rather than like policy."
  default     = true
}

variable "from_namespaces" {
  type        = list(string)
  description = "Namespace names whose pods may open connections in. Whole-namespace guests, any pod, any port. A name given twice collapses to one rule. Shorthand for a from_peers entry with no pod_selector and no ports -- when you know the pods or the port, say so there instead."
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
  description = "Explicit cross-namespace guests: `{ namespace, pod_selector = <labels or null>, pod_selector_expressions = <expressions or null>, ports = [{port, protocol}] }`. One guest per rule, rendered in list order after from_cidrs, so each carries its own ports. Ports are the *destination pod's* ports, not the Service's -- kube-proxy DNATs before ingress is evaluated, the same trap as the egress direction. A null/omitted `pod_selector` means every pod in that namespace; an empty `ports` means every port -- both are the exception, since naming pods and ports is the point of this variable. Give `pod_selector_expressions` to name the guest by a `NotIn`/`Exists` instead of exact labels -- both selectors land in the one peer, so they AND."
  default     = []
}

variable "allow_nodes" {
  type        = bool
  description = "Allow each node's two addresses -- InternalIP and Calico IPIP tunnel address -- to whatever these pods listen on. This is the direction's floor, not a guest list: kubelet probes arrive from the hosting node's InternalIP, and a cross-node apiserver call arrives from the *sending* node's tunnel address, so turning it off makes every governed pod go NotReady and breaks every admission webhook. On by default; a failed node read drops the rule rather than widening it."
  default     = true
}

variable "allow_cluster" {
  type        = bool
  description = "Allow the pod CIDR wholesale: any pod in the cluster, on any port. Rare -- prefer from_namespaces. Read from kubeadm-config; there is no service-CIDR peer because a source is never a ClusterIP (DNAT rewrites the destination, not the source)."
  default     = false
}

variable "allow_internet" {
  type        = bool
  description = "Allow public source addresses: 0.0.0.0/0 minus RFC1918 and link-local. For a WAN-forwarded LoadBalancer. Not a blanket -- the LAN, the nodes and every pod are subtracted, so a LAN client needs from_cidrs or allow_nodes instead."
  default     = false
}

variable "from_cidrs" {
  type        = list(string)
  description = "Extra source CIDRs to allow, one ipBlock peer each. Escape hatch for the LAN, a single NAS or off-cluster host, or one address a guest namespace cannot express."
  default     = []
}
