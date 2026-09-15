variable "name" {
  type        = string
  description = "NetworkPolicy metadata.name (unique per namespace)."
}

variable "namespace" {
  type = string
}

# Which pods this policy applies to. Empty = whole namespace.
variable "pod_selector" {
  type    = map(string)
  default = {}
}

# Subset of ["Ingress", "Egress"].
variable "policy_types" {
  type = list(string)
}

# Rules, same shape in both directions:
#   {
#     peers = [
#       { namespace_selector = { "kubernetes.io/metadata.name" = "kube-network" } },
#       { namespace_selector = {...}, pod_selector = { "k8s-app" = "kube-dns" } },
#       { ip_block = { cidr = "0.0.0.0/0", except = ["10.0.0.0/8"] } },
#     ]
#     ports = [{ protocol = "TCP", port = 6443 }]   # optional; omitted = any
#   }
# Typed `any`, not `list(any)`: peer shapes differ and `list(any)` would force every
# element to one type.
variable "ingress_rules" {
  type    = any
  default = []
}

variable "egress_rules" {
  type    = any
  default = []
}