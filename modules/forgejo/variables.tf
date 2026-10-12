variable "namespace" { default = "devops-forgejo" }
variable "name" { default = "forgejo" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }

variable "host_network" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# Only the OIDC egress peer uses this: authentik is served by the private gateway.
variable "auth_gateway_name" { default = "private" }

# Web host is <hostname>.<domain>; the SSH VIP carries its own name because it is a second IP.
variable "hostname" { default = "git" }
variable "ssh_hostname" { default = "ssh.git" }

variable "oidc_issuer_base" {
  type        = string
  description = "authentik root URL, e.g. https://auth.example.net. The issuer is derived from it and this module's name."
}

variable "chart_repository" {
  type        = string
  default     = "oci://code.forgejo.org/forgejo-helm"
  description = "OCI registry the official Forgejo chart lives in."
}

variable "chart" { default = "forgejo" }

variable "chart_version" {
  type        = string
  default     = "17.2.0"
  description = "Forgejo chart version; its appVersion is the Forgejo release it ships."
}

variable "image_registry" { default = "code.forgejo.org" }
variable "image_repository" { default = "forgejo/forgejo" }
variable "image_tag" { default = "16.0.5" }

# The advertised/public SSH endpoint: the DNS name and the MetalLB VIP port.
variable "ssh_port" { default = 22 }

# The port sshd binds inside the rootless image. It defaults to 2222 because the rootless image
# cannot bind <1024; the Service DNATs 22 -> here, and the NetworkPolicy matches on this
# post-DNAT port rather than the VIP port.
variable "ssh_listen_port" { default = 2222 }

variable "port" { default = 3000 }

variable "vpn_namespace" { default = "kube-network-vpn" }

# Break-glass local admin, for when authentik is unreachable. `admin` is a Forgejo reserved
# username, hence breakglass; its password is chart-generated and lives only in the release's
# <name>-admin Secret.
variable "admin_username" { default = "breakglass" }
variable "admin_email" { default = "admin@linuxguru.net" }

variable "storage_class" { default = "longhorn" }
variable "data_size" { default = "20Gi" }

# Forgejo's [storage] subsystems (LFS, attachments, avatars, packages, ...) go to this
# SeaweedFS S3 bucket; the DB and the git repositories stay on the longhorn claim. The
# endpoint is the gateway-fronted name, so TLS is trusted by the default roots.
variable "s3_endpoint" { default = "s3.vn.linuxguru.net" }
variable "s3_bucket" { default = "forgejo" }
