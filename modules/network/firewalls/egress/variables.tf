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
  description = "Prefix for a generated metadata.name, `<name_prefix>-<8 hex>`. Ignored when name is set. Defaults to namespace-egress, so a call that omits both is still uniquely named."
  default     = null
}

# Naming: `allow_*` are the on/off switches, `to_*` take explicit peer lists.
variable "allow_namespace" {
  type        = bool
  description = "Allow egress to THIS namespace's own pods -- the self rule, rendered first. Peers in other namespaces are to_namespaces (plural). On by default: intra-namespace traffic is implicit in nearly every app, and losing it looks like a broken application rather than like policy."
  default     = true
}

variable "to_namespaces" {
  type        = list(string)
  description = "Namespace names whose pods may be reached. Whole-namespace peers, no pod selector. A name given twice collapses to one rule."
  default     = []
}

variable "allow_k8s_api" {
  type        = bool
  description = "Allow the API server, as two rules: TCP/6443 to the control-plane node addresses, plus TCP/443 to the kubernetes Service ClusterIP. kube-proxy DNATs a ClusterIP dial before policy runs, so the node-address rule is the one that matches on this cluster; the ClusterIP rule covers a dataplane matching pre-DNAT."
  default     = false
}

variable "allow_cluster" {
  type        = bool
  description = "Allow the pod CIDR and the service CIDR wholesale. Rare: prefer to_namespaces."
  default     = false
}

variable "allow_internet" {
  type        = bool
  description = "Allow 0.0.0.0/0 minus RFC1918 and link-local. Never reaches the LAN."
  default     = false
}

variable "to_cidrs" {
  type        = list(string)
  description = "Extra CIDRs to allow, one ipBlock peer each. Escape hatch for a single NAS, an off-cluster host, or the whole LAN."
  default     = []
}
