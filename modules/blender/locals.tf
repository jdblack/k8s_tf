locals {
  samba_name = "${var.name}-samba"
  pv_name    = "${var.namespace}-${var.name}"

  samba_host = "samba-${var.name}.${var.domain}"

  mdns_name = "${var.name}-mdns"

  samba_vip = try(kubernetes_service_v1.samba.status[0].load_balancer[0].ingress[0].ip, "")
}
