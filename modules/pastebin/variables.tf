variable "namespace" { default = "pastebin" }
variable "name" { default = "pastebin" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }

# The app is public; authentik stays on the private gateway.
variable "gateway_name" { default = "public" }
variable "gateway_namespace" { default = "kube-network" }

# Only the OIDC egress peer uses this: authentik is served by the private gateway.
variable "auth_gateway_name" { default = "private" }

variable "oidc_issuer_base" {
  type        = string
  description = "authentik root URL, e.g. https://auth.example.net. The issuer is derived from it and this module's name, which is the slug the OIDC application is created with."
}

variable "app_name" { default = "Pastebin" }

variable "image" { default = "ghcr.io/smp46/pingvin-share-x" }
variable "image_tag" { default = "v2.0.0" }

variable "port" { default = 3000 }

variable "storage_class" { default = "longhorn" }

# The SQLite database and every uploaded file, so it grows with the shares.
variable "data_size" { default = "50Gi" }
