variable "namespace" {
  type        = string
  description = "Namespace whose pods this policy governs -- and where the policy object lives."
}

variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the governed pods. Empty (default) = every pod in the namespace."
  default     = {}
}

variable "policy_name" {
  type        = string
  description = "Name of the NetworkPolicy object. One call renders one object, so a namespace with several calls needs distinct names."
  default     = "namespace-egress"
}

variable "to_namespaces" {
  type        = list(string)
  description = "Namespace names whose pods may be reached. Whole-namespace peers, no pod selector."
  default     = []
}

variable "to_k8s_api" {
  type        = bool
  description = "Allow TCP/6443 to the API server: the kubernetes Service ClusterIP plus the control-plane node addresses."
  default     = false
}

variable "api_peer_ips" {
  type        = list(string)
  description = "Override the IPs used by to_k8s_api. Empty = read them from the kubernetes Endpoints object."
  default     = []
}

variable "to_cluster" {
  type        = bool
  description = "Allow the pod CIDR and the service CIDR wholesale. Rare: prefer to_namespaces."
  default     = false
}

variable "to_internet" {
  type        = bool
  description = "Allow 0.0.0.0/0 minus RFC1918 and link-local. Never reaches the LAN."
  default     = false
}

variable "to_cidrs" {
  type        = list(string)
  description = "Extra CIDRs to allow, one ipBlock peer each. Escape hatch for LAN/NAS/off-cluster peers."
  default     = []
}
