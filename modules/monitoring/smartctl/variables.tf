variable "name" { default = "smartctl" }
variable "namespace" {}

# prometheus-smartctl-exporter chart version.
# 0.17.1 renders the identical DaemonSet to 0.16.0 (same image
# quay.io/prometheuscommunity/smartctl-exporter:v0.14.0) -- chart-only change.
variable "helm_version" { default = "0.17.1" }
