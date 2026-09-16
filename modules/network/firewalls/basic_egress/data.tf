# Pods reach the apiserver via the kubernetes.default.svc ClusterIP plus its real endpoint
# IPs (the control-plane nodes); both fall inside blocked_egress_cidrs, so pods needing the
# API require explicit carve-outs. Calico evaluates egress policy post-DNAT, so the ENDPOINT
# IP is what must be allowed. Read only when the caller did not hand the IPs in -- see
# var.api_peer_ips for why that matters.
data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.allow_k8s_api && var.api_peer_ips == null ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
