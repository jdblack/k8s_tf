variable "namespace" {}
variable "longhorn_namespace" { default = "longhorn-system" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
variable "helm_longhorn_version" { default = "1.12.1" }

# snapshot-controller chart version.
variable "helm_snapshot_controller_version" { default = "5.2.0" }
