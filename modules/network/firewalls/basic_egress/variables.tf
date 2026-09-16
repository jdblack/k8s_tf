variable "namespace" { type = string }

# Only has to differ when several firewall policies share a namespace.
variable "policy_name" { default = "namespace-firewall" }

# Which pods HERE this policy applies to. Empty = the whole namespace.
#
# Setting it makes the policy pod-scoped, which is how a namespace grants something to a
# SUBSET of its pods (the shape `allow_api` used to have): the API carve-out for one
# controller, the hook Job that carries only batch labels, ... NetworkPolicies union, so a
# pod-scoped policy with its own `policy_name` ADDS to the namespace-wide one; it never
# narrows it.
variable "pod_selector" {
  type        = map(string)
  description = "Labels selecting the pods this policy applies to (empty = whole namespace)."
  default     = {}
}

# One rule per entry, in this order. The namespace's own pods are NOT implied -- list
# var.namespace to keep talking to them. Order matters: these render first, and the provider
# compares the spec as rendered, so reordering rewrites every policy built on this module.
variable "allow_namespaces" {
  type        = list(string)
  description = "Namespaces whose pods these pods may reach (e.g. kube-network for gateway-hosted URLs, then this one)."
  default     = []
}

# Each entry becomes its own rule, so it wins over blocked_egress_cidrs.
variable "allow_cidrs" {
  type        = list(string)
  description = "Specific CIDRs (e.g. 192.168.0.50/32) pods may egress to despite blocked_egress_cidrs."
  default     = []
}

# Off unless asked for: internet egress is the loudest thing a namespace can have, and the
# only posture that lets a compromise dial out.
variable "allow_internet" { default = false }

# Carve-out: the apiserver ClusterIP and its endpoint IPs both fall inside
# blocked_egress_cidrs.
variable "allow_k8s_api" { default = false }

# Pass these in when this module sits under a module-level `depends_on`, which covers data
# sources too -- the peer count is then guessed at plan and real at apply, and the apply
# dies with "inconsistent final plan". null = read here.
variable "api_peer_ips" {
  type    = list(string)
  default = null
}

# kubernetes.default is the first host of the service CIDR; keep in sync with
# --service-cluster-ip-range.
variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}
