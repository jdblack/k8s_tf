variable "namespace" { default = "mcp" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# TypingMind shows this token in the connector dialog and signs every request with it.
variable "auth_token" {
  type      = string
  sensitive = true
}

# ★ DECLARED SCALE, not a hand scale (2026-10-17). `0` keeps the store and stops the workload, so
# `stacks/mantle` can be applied without resurrecting the old self. Rollback = set 1.
variable "ellmephant_replicas" {
  type    = number
  default = 1
}
