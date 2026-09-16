variable "namespace" {}
variable "longhorn_namespace" { default = "longhorn-system" }

variable "helm_longhorn_url" { default = "https://charts.longhorn.io" }
variable "helm_longhorn_chart" { default = "longhorn" }
variable "helm_longhorn_version" { default = "1.12.1" }

# snapshot-controller chart version.
variable "helm_snapshot_controller_version" { default = "5.2.0" }

# The apiserver's endpoint IPs, read by the CALLER (stack root) and passed to the
# firewall's API carve-out. Required whenever this module is called under a module-level
# `depends_on`: that defers data sources inside the module to apply time, so the API netpol
# plans a guessed peer count and the apply dies with "inconsistent final plan".
#
# null = let the firewall module read the endpoints itself (fine only for callers with no
# module-level depends_on).
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
