locals {
  samba_name = "${var.name}-samba"
  pv_name    = "${var.namespace}-${var.name}"

  # The name external-dns publishes for the SMB Service AND the SRV target the mDNS
  # advertiser hands out (mdns.tf), so the two cannot drift.
  samba_host = "samba-${var.name}.${var.domain}"

  # The advertiser's ConfigMap/Deployment name. Deliberately NOT "${...}-samba": that
  # string is the samba Service's pod selector, and a hostNetwork pod matching it would
  # register <node-ip>:445 as an SMB endpoint (mdns.tf).
  mdns_name = "${var.name}-mdns"

  # The MetalLB VIP, read back off the Service. Empty until MetalLB allocates one -- then
  # no address record is published and clients resolve the SRV target via unicast DNS.
  samba_vip = try(kubernetes_service_v1.samba.status[0].load_balancer[0].ingress[0].ip, "")
}
