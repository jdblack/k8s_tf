variable "namespace" {}
variable "longhorn_namespace" { default = "longhorn-system" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
