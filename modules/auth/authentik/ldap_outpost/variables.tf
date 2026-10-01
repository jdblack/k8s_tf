variable "namespace" {
  type        = string
  default     = "kube-auth"
  description = "Namespace the outpost Deployment, Service and credential Secrets live in."
}

variable "outpost_name" {
  type        = string
  default     = "ldap"
  description = "Outpost, LDAP provider and application all take this name; LDAP providers serve under their own Base DN, so this is what tells two of them apart."
}

variable "service_name" {
  type    = string
  default = "authentik-ldap"
}

variable "group_name" {
  type        = string
  default     = "ldap"
  description = "Group allowed to bind and search. It must be its own group: reusing an app's group would let every one of its members bind."
}

variable "base_dn" {
  type        = string
  default     = "DC=ldap,DC=goauthentik,DC=io"
  description = "Directory root. Each LDAP provider needs a unique one, so a second provider must prepend an OU here."
}

variable "bind_user" {
  type        = string
  default     = "ldapservice"
  description = "Account the consumer binds and searches with. It has to be a plain user: the bind flow runs the standard identification and password stages."
}

variable "bind_mode" {
  type        = string
  default     = "direct"
  description = "direct hits the core API per bind; cached reuses the result for the session duration."
}

variable "search_mode" {
  type        = string
  default     = "direct"
  description = "direct always returns fresh data; cached holds the whole directory in the outpost and can go stale."
}

variable "bind_flow_slug" {
  type        = string
  default     = "default-authentication-flow"
  description = "Flow a bind request runs. The default works for a bind-only account because it has no MFA device."
}

variable "unbind_flow_slug" {
  type        = string
  default     = "default-provider-invalidation-flow"
  description = "Flow run on unbind; the same flow the proxy providers here use."
}

variable "domain" { type = string }

variable "auth_fqdn" {
  type    = string
  default = null
}

variable "core_namespace" {
  type    = string
  default = "kube-auth"
}

variable "image" { default = "ghcr.io/goauthentik/ldap" }

variable "image_tag" {
  type        = string
  default     = "2026.8.2"
  description = "Must match the authentik server version."
}

variable "ldap_port" {
  type        = number
  default     = 3389
  description = "Container's plaintext LDAP port. Not 389: the outpost binds unprivileged."
}

variable "ldaps_port" {
  type        = number
  default     = 6636
  description = "Container's LDAPS port. Not 636, for the same reason."
}

variable "metrics_port" { default = 9300 }

variable "password_length" {
  type    = number
  default = 40
}

variable "certificate_pem" {
  type        = string
  default     = null
  description = "Optional LDAPS certificate. Left null the outpost serves its own self-signed cert, which has no SAN and so only works with verification off."
}

variable "certificate_key_pem" {
  type      = string
  default   = null
  sensitive = true
}
