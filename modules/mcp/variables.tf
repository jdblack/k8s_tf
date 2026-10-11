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
