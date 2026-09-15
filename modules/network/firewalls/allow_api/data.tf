# The Kubernetes API server is reached via the kubernetes.default.svc ClusterIP
# plus the apiserver's real endpoint IPs (the control-plane nodes). Calico
# evaluates egress policy post-DNAT, so the ENDPOINT IP is what must be allowed
# -- track it dynamically so a control-plane IP change doesn't silently break
# consumers. Identical to basic_internet/data.tf (that module only reads it
# when allow_to_k8sapi is on; this module always needs it).
#
# Read only when the caller did not hand the IPs in (var.api_peer_ips = null).
# The read MUST be off when this module sits under a module-level `depends_on`
# -- see var.api_peer_ips for why.
data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.api_peer_ips == null ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
