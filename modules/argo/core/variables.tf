

variable "namespace" { default = "argo" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }

# Off by default because Argo Workflows runs arbitrary user pods in this namespace;
# see modules/argo/core/security.tf.
variable "enable_egress_firewall" { default = false }


