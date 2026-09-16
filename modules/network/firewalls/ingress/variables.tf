variable "namespace" {
  type        = string
  description = "Namespace whose pods this policy governs -- and where the policy object lives."
}

variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the governed pods -- the DESTINATION, not the guest. Empty (default) = every pod in the namespace. A guest's own labels go in from_peers, never here."
  default     = {}
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

# Naming: `allow_*` are the on/off switches, `from_*` take explicit guest lists.
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

# `from_*` takes an explicit guest list; this is the one that can also say *which pods* and *which
# ports*, which a from_namespaces guest cannot.
variable "from_peers" {
  type = list(object({
    namespace    = string
    pod_selector = optional(map(string))
    ports = optional(list(object({
      port     = number
      protocol = optional(string, "TCP")
    })), [])
  }))
  description = "Explicit cross-namespace guests: `{ namespace, pod_selector = <labels or null>, ports = [{port, protocol}] }`. One guest per rule, rendered in list order after from_cidrs, so each carries its own ports. Ports are the *destination pod's* ports, not the Service's -- kube-proxy DNATs before ingress is evaluated, the same trap as the egress direction. A null/omitted `pod_selector` means every pod in that namespace; an empty `ports` means every port -- both are the exception, since naming pods and ports is the point of this variable."
  default     = []
}

variable "allow_nodes" {
  type        = bool
  description = "Allow the node addresses: TCP from each node's InternalIP to whatever these pods listen on. This is the direction's floor, not a guest list -- kubelet health probes and the apiserver's own calls into a pod originate on the node, so turning it off makes every governed pod go NotReady. On by default; a failed node read drops the rule rather than widening it."
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
