locals {
  samba_name = "${var.name}-samba"
  pv_name    = "${var.namespace}-${var.name}"

  # The name external-dns publishes for the SMB Service, and the name the mDNS
  # advertiser hands out as its SRV target (see mdns.tf). One source of truth so
  # the two cannot drift.
  samba_host = "samba-${var.name}.${var.domain}"

  # The advertiser's ConfigMap/Deployment name. Deliberately NOT "${...}-samba":
  # that string is the samba Service's pod selector, and a hostNetwork pod
  # matching it would register <node-ip>:445 as an SMB endpoint (see mdns.tf).
  mdns_name = "${var.name}-mdns"

  # The MetalLB VIP, read back off the Service. Empty on a fresh cluster until
  # MetalLB allocates one -- in that case no address record is published in
  # mDNS and clients resolve the SRV target through unicast DNS instead.
  samba_vip = try(kubernetes_service_v1.samba.status[0].load_balancer[0].ingress[0].ip, "")
}
