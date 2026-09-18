locals {
  fqdn = "${var.name}.${var.domain}"

  auth_trusted_cidrs = join(",", [var.pod_cidr, var.host_cidr])

  config_dir = "/app/config/config_files"
  config_pvc = "${var.name}-config"
}
