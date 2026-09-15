# The Kubernetes API server is reached via the kubernetes.default.svc ClusterIP
# plus the apiserver's real endpoint IPs (control-plane nodes). Both fall inside
# blocked_egress_cidrs, so pods needing the API server require explicit carve-outs.
# Calico evaluates egress policy post-DNAT, so the ENDPOINT IP is what must be
# allowed -- track it dynamically so a control-plane IP change doesn't break
# consumers. Only read when the flag is on, and only when the caller did not
# hand the IPs in (var.api_peer_ips = null) -- see that variable for why a
# module-level `depends_on` on the caller must disable this read.
data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.allow_to_k8sapi && var.api_peer_ips == null ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
