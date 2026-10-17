variable "namespace" { default = "devops-forgejo" }
variable "name" { default = "forgejo" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }

variable "host_network" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# The egress peer the namespace's NetworkPolicy admits: the private gateway pod serves both
# authentik (OIDC discovery, token exchange) and SeaweedFS (s3.<domain>), so this name carries S3
# traffic as well as auth. It is not an auth-only knob.
# The egress peer the namespace's NetworkPolicy admits: the private gateway pod serves both
# authentik (OIDC discovery, token exchange) and SeaweedFS (s3.<domain>), so this name carries S3
# traffic as well as auth. It is not an auth-only knob.
variable "auth_gateway_name" { default = "private" }

variable "agent_namespaces" {
  type        = list(string)
  default     = []
  description = "Selves' rooms whose hands may clone/push over HTTP in-cluster. Each gets an ingress peer on the WEB port only — never SSH, never any other port."

  validation {
    condition     = alltrue([for ns in var.agent_namespaces : ns != var.namespace])
    error_message = "The agent room list must not contain Forgejo's own namespace; the namespace already admits itself."
  }
}


# Web host is <hostname>.<domain>; the SSH VIP carries its own name because it is a second IP.
variable "hostname" { default = "git" }
variable "ssh_hostname" { default = "ssh.git" }

# OIDC is an input now, not a submodule: the client is created by an authentik blueprint in the same
# stack, and these exact strings decide what lands in the login_source row. A wrong scopes or
# group_claim is silent -- login keeps working and nobody has rights -- so they are validated here.
#
# The group names are the ones the blueprint creates from its own `name` variable; both stacks pass
# `forgejo`, and each side checks its own consistency (see the last validation).
variable "oidc" {
  type = object({
    client_id        = string
    client_secret    = string
    discovery_url    = string
    scopes           = string
    group_claim      = string
    admin_group      = string
    restricted_group = string
  })

  # Not `sensitive = true` on the whole object: only the secret is, and marking the object would hide
  # the scopes and group names too -- the values this input most needs to be reviewed for.

  validation {
    # Forgejo reads this as StringSliceFlag on the comma: a space-separated list is not "wrong", it is
    # ONE scope named "openid email profile groups", which validates and grants nothing.
    condition     = !strcontains(var.oidc.scopes, " ")
    error_message = "oidc.scopes must be comma-separated with no spaces; Forgejo splits it on the comma only."
  }

  validation {
    # Without openid there is no id token; without groups, `admin_group`/`restricted_group` never match
    # and every user lands unprivileged with no error anywhere.
    condition     = contains([for s in split(",", var.oidc.scopes) : trimspace(s)], "openid")
    error_message = "oidc.scopes must include openid."
  }

  validation {
    condition     = contains([for s in split(",", var.oidc.scopes) : trimspace(s)], "groups")
    error_message = "oidc.scopes must include groups, or the group claim is empty and nobody is ever an admin."
  }

  validation {
    condition     = length(trimspace(var.oidc.client_id)) > 0 && length(trimspace(var.oidc.discovery_url)) > 0
    error_message = "oidc.client_id and oidc.discovery_url must not be empty."
  }

  validation {
    # The blueprint builds the groups as <its name>-admin / -user and this module names the source's
    # admin/restricted groups from the input; the two are only linked by the stack passing the same
    # literal to both. Tying them to this module's own `name` makes half of that link structural.
    condition     = var.oidc.admin_group == "${var.name}-admin" && var.oidc.restricted_group == "${var.name}-user"
    error_message = "oidc.admin_group/restricted_group must be <name>-admin and <name>-user: those are the group names the authentik blueprint creates."
  }
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
