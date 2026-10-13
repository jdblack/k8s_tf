variable "namespace" {
  type        = string
  description = "Namespace the blueprint Secret lands in. It has to be the authentik namespace, or the chart never mounts the Secret and the blueprint is silently never applied."
}

variable "name" {
  type        = string
  default     = "forgejo"
  description = "Object prefix. Load-bearing: the groups derive as <name>-admin/<name>-user, and the client is configured to read exactly those names, so any other value leaves login working with nobody an admin and no error anywhere."

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty; it is the prefix of every object and both group names."
  }
}

variable "issuer_base" {
  type        = string
  description = "Base URL the OIDC issuer and discovery document are built from, e.g. https://auth.example.net -- no trailing slash, the issuer path is appended directly."

  validation {
    condition     = !endswith(var.issuer_base, "/")
    error_message = "issuer_base must not end in a slash: the issuer path is appended directly, and a doubled slash is a different issuer."
  }
}

variable "domain" {
  type        = string
  description = "Cluster domain the redirect URIs are built from (git.<domain>)."
}
