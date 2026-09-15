variable "namespace" {}
variable "name" { default = "authentik" }
variable "helm_version" { default = "2025.10.3" }
variable "domain" {}
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# The apiserver's endpoint IPs, read by the CALLER (stack root) and passed through to
# the pod-scoped allow_api firewall -- see ../../network/firewalls/allow_api/variables.tf
# for the `depends_on` + data-source "inconsistent final plan" gotcha.
#
# null = let the firewall module read the endpoints itself (fine only for callers
# with no module-level depends_on).
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
