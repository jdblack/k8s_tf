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

# See helm.tf for why this only moves in a deliberate, dedicated change.
variable "helm_version" {
  type    = string
  default = "0.46.4"
}

variable "domain" {
  type = string
}

# Issuer for this host's own ListenerSet -- leaf cert only.
variable "cert_issuer" {
  type = string
}

# Authentik host used as the SSO issuer for the Workflows UI.
variable "oauth2_server" {
  type = string
}

# authentik's built-in superuser group, matched in addition to the app's own
# `<name>-admin` group. Must match the `groups` claim exactly.
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
