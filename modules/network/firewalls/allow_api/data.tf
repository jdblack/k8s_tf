# The apiserver is reached via the kubernetes.default.svc ClusterIP plus its real
# endpoint IPs (the control-plane nodes). Calico evaluates egress policy post-DNAT, so
# the endpoint IP is what must be allowed -- tracked dynamically so a control-plane
# re-IP doesn't silently break consumers.
#
# Read only when the caller did not hand the IPs in -- see var.api_peer_ips.
data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.api_peer_ips == null ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
