variable "namespace" { type = string }
variable "name" { default = "argo-events" }

variable "repo" { default = "https://argoproj.github.io/argo-helm" }
variable "chart" { default = "argo-events" }

variable "helm_version" { default = "2.4.27" }

variable "gateway_name" {
  type    = string
  default = "private"
}

variable "gateway_namespace" {
  type    = string
  default = "kube-network"
}
