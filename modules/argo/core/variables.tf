

variable "namespace" { default = "argo" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }

# Opt-in egress firewall for the Argo namespace (modules/argo/core/security.tf).
# Defaults to off because Argo Workflows runs arbitrary user pods in this
# namespace; flip it on only after auditing that workflow steps never egress
# to services in other namespaces directly.
variable "enable_egress_firewall" { default = false }


