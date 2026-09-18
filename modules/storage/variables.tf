variable "namespace" {}
variable "longhorn_namespace" { default = "longhorn-system" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "monitoring_namespace" { default = "monitoring" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
variable "helm_longhorn_version" { default = "1.12.1" }
