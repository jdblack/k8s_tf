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

# See helm.tf for why this only moves in a dedicated change. 2.0.6 = app v4.1.3 (two chart majors and
# one app major on from 0.46.4); the rendered Deployments differ only in the image tag, chart labels,
# `checksum/cm` and a new `strategy: Recreate`. 1.x/2.x install the 8 argo CRDs from a `pre-upgrade`
# hook Job rather than as templated resources, and Helm deletes resources that leave a manifest -- so
# those CRDs were annotated `helm.sh/resource-policy: keep` once, by hand, before this bump.
variable "helm_version" {
  type    = string
  default = "2.0.6"
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

# authentik's built-in superuser group, matched in addition to the app's own `<name>-admin`; must match
# the `groups` claim exactly.
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
