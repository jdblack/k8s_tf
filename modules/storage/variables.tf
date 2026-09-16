variable "namespace" {}
variable "longhorn_namespace" { default = "longhorn-system" }

# The private gateway's data plane is the only outside peer these pods have (the three HTTPRoutes in
# this namespace); the same names the seaweedfs module defaults to.
variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# Prometheus, which scrapes the `metrics` port of every SeaweedFS chart pod.
variable "monitoring_namespace" { default = "monitoring" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
variable "helm_longhorn_version" { default = "1.12.1" }

# snapshot-controller chart version.
variable "helm_snapshot_controller_version" { default = "5.2.0" }
