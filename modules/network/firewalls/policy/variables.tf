# The library's single NetworkPolicy renderer. The public presets
# (basic_internet / limited_ingress / allow_api) and any bespoke caller build
# explicit rule lists and hand them here -- so the "rule object -> typed
# kubernetes_network_policy_v1" translation exists once, not per preset.

variable "name" {
  type        = string
  description = "NetworkPolicy metadata.name (unique per namespace)."
}

variable "namespace" {
  type = string
}

# Which pods this policy applies to. Empty = `podSelector: {}` = whole namespace.
variable "pod_selector" {
  type    = map(string)
  default = {}
}

# Subset of ["Ingress", "Egress"].
variable "policy_types" {
  type = list(string)
}

# Rule lists. Rule shape (same for both directions):
#   {
#     peers = [
#       { namespace_selector = { "kubernetes.io/metadata.name" = "kube-network" } },
#       { namespace_selector = {...}, pod_selector = { "k8s-app" = "kube-dns" } },
#       { ip_block = { cidr = "0.0.0.0/0", except = ["10.0.0.0/8"] } },
#     ]
#     ports = [{ protocol = "TCP", port = 6443 }]   # optional; omitted = any
#   }
# Typed `any` (not `list(any)`): rule/peer shapes differ between entries (some
# ip_block, some namespace_selector; optional ports), and `list(any)` would
# force every element to the same type.
variable "ingress_rules" {
  type    = any
  default = []
}

variable "egress_rules" {
  type    = any
  default = []
}