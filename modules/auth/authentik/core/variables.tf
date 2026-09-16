variable "namespace" {}
variable "name" { default = "authentik" }

# Chart == app version, and authentik **refuses major version skips**: the jump fails inside
# run_migrations() and surfaces only as "the server has exited unexpectedly", so step one release per
# apply -- 2025.10.3 -> 2025.12.4 -> 2026.2.3 -> 2026.5.6 -> 2026.8.2 -- each running its own migrations.
variable "helm_version" { default = "2026.8.2" }

# Calico's pod CIDR from tfvars: NGF's data plane is the only client sending X-Forwarded-* and it
# dials the server pod directly from the pod network, so this is the whole trusted-proxy list.
variable "pod_cidr" { type = string }

variable "domain" {}
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
