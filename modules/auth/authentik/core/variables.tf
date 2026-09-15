variable "namespace" {}
variable "name" { default = "authentik" }
variable "domain" {}
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# The apiserver's endpoint IPs, read by the CALLER (stack root) and passed
# through to the pod-scoped allow_api firewall. Required whenever this module is
# called under a module-level `depends_on` -- which it is (stacks/core/auth.tf
# depends on module.cert_man + module.storage): `depends_on` defers data sources
# inside the module to apply time, and the API netpol then plans a guessed peer
# count and the apply dies with "inconsistent final plan". See
# ../../network/firewalls/allow_api/variables.tf.
#
# null = let the firewall module read the endpoints itself (fine only for
# callers with no module-level depends_on).
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
