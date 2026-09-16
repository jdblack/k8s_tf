variable "namespace" { type = string }
variable "name" { default = "argo-cd" }
variable "domain" { type = string }
variable "cert_issuer" { type = string }

variable "repo" { default = "https://argoproj.github.io/argo-helm" }
variable "chart" { default = "argo-cd" }

# argo-cd chart version. Bump deliberately, in its own change: the chart owns the
# CRDs and the names other modules bind to.
variable "helm_version" { default = "10.9.1" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
