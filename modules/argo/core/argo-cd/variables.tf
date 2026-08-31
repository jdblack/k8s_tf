variable "namespace" { type = string }
variable "name" { default = "argo-cd" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }

variable "repo" { default = "https://argoproj.github.io/argo-helm" }
variable "chart" { default = "argo-cd" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
