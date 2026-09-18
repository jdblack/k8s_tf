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

variable "helm_version" {
  type    = string
  default = "2.0.6"
}

variable "domain" {
  type = string
}

variable "cert_issuer" {
  type = string
}

variable "oauth2_server" {
  type = string
}

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
