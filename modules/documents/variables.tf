variable "namespace" { default = "documents" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "auth_namespace" { default = "kube-auth" }
variable "monitoring_namespace" { default = "monitoring" }

variable "hostname" { default = "drive" }

# The LDAP outpost lives in kube-auth, one directory per provider, so oCIS is handed the
# bind DN and base DNs rather than deriving them.
variable "ldap_uri" { type = string }
variable "ldap_bind_dn" { type = string }
variable "ldap_user_base_dn" { type = string }
variable "ldap_group_base_dn" { type = string }

# Passed as a value, not looked up: the bind Secret lives in kube-auth, and oCIS can only
# read Secrets from its own namespace.
variable "ldap_bind_password" {
  type      = string
  sensitive = true
}

variable "oidc_issuer_base" { type = string }
