variable "namespace" { type = string }

variable "name" { default = "typingmind-mcp" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "auth_token" {
  type      = string
  sensitive = true
}

variable "image" { default = "harbor.vn.linuxguru.net/library/typingmind-mcp" }

# Pinned: this is our own build rather than an upstream release tag, so `latest`
# would silently drift under the deployment on any re-push.
variable "image_tag" { default = "v1.0.3" }

variable "port" { default = 8080 }

# Caps a single tool call; the upstream default of 60s is tight for anything that thinks.
variable "timeout_ms" { default = 120000 }
