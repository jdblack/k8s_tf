variable "namespace" {}
variable "name" { default = "authentik" }

# Chart == app version, and authentik **refuses major version skips**. Jumping 2025.10.3 ->
# 2026.8.2 fails inside run_migrations():
#   [error] Major version skips are not allowed. ...?from=2025.10.3&to=2026.8.2
# and the container surfaces that only as "the server has exited unexpectedly"
# (src/server/mod.rs:245) -- which is what this module was pinned for. So step through one
# release per apply, each running its own DB migrations:
#   2025.10.3 -> 2025.12.4 -> 2026.2.3 -> 2026.5.6 -> 2026.8.2
# Verified against the DB before starting: no duplicate group names (the 2025.12 migration
# fails loudly on those), and PGDATA/mountPath are unchanged across the postgres subchart.
variable "helm_version" { default = "2026.8.2" }

# Calico's pod CIDR from tfvars. The only client that sends X-Forwarded-* to authentik is
# NGF's data plane, and it dials the server pod directly from the pod network, so this is
# the whole trusted-proxy list (2026.8 started ignoring forwarded headers from anywhere
# else).
variable "pod_cidr" { type = string }

variable "domain" {}
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# The apiserver's endpoint IPs, read by the CALLER (stack root) and passed to the
# pod-scoped API firewall -- see ../../network/firewalls/basic_egress/variables.tf for
# the `depends_on` + data-source "inconsistent final plan" gotcha.
#
# null = let the firewall module read the endpoints itself (fine only for callers with no
# module-level depends_on).
variable "api_peer_ips" {
  type    = list(string)
  default = null
}
