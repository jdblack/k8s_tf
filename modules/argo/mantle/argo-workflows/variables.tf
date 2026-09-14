variable "namespace" {
  type = string
}

variable "name" {
  type    = string
  default = "argo-wf"
}

variable "repo" {
  type    = string
  default = "https://argoproj.github.io/argo-helm"
}

variable "chart" {
  type    = string
  default = "argo-workflows"
}

# Pin to the chart version currently running in the cluster.  See helm.tf for
# why this should only move in a deliberate, dedicated change.
variable "chart_version" {
  type    = string
  default = "0.46.4"
}

variable "domain" {
  type = string
}

# Issuer for this host's own ListenerSet (argo-wf.vn) -- leaf cert only. The
# SSO clients validate authentik against the container's public roots.
variable "cert_issuer" {
  type = string
}

# Authentik host used as the SSO issuer for the Workflows UI.
variable "oauth2_server" {
  type = string
}

# Global-admin group, matched in addition to the app's own `<name>-admin`
# group.  This is authentik's built-in superuser group; its name is a literal
# (authentik ships it), and it must match exactly as it appears in the `groups`
# claim.
variable "admin_group" {
  type    = string
  default = "authentik Admins"
}

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}
