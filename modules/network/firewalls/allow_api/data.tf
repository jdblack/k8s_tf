# The apiserver is reached via the kubernetes.default.svc ClusterIP plus its real
# endpoint IPs (the control-plane nodes). Calico evaluates egress policy
# post-DNAT, so the ENDPOINT IP is what must be allowed -- tracked dynamically so
# a control-plane re-IP doesn't silently break consumers.
#
# Read only when the caller did not hand the IPs in; must stay off under a
# module-level `depends_on` -- see var.api_peer_ips.
data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.api_peer_ips == null ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
