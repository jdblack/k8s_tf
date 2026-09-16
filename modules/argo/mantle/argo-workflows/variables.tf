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
#
# 2.0.6 = app v4.1.3 (two chart majors and one app major on from 0.46.4/v3.7.7). Two
# consequences worth knowing before the next bump:
#   * the rendered server/controller Deployments differ from 0.46.4 only in the image tag,
#     the chart-version labels, `checksum/cm`, and a new `strategy: Recreate` on the
#     controller -- the SSO/auth args our values drive are byte-identical.
#   * 1.x/2.x stopped rendering the 8 argo CRDs as ordinary templated resources and now
#     installs them from a `pre-upgrade` hook Job (crdinstaller). Helm deletes resources that
#     leave a manifest, so the CRDs were annotated `helm.sh/resource-policy: keep` once, by
#     hand, before this bump -- verified still present afterwards.
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
