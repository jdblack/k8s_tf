# The Kubernetes API server is reached via the kubernetes.default.svc ClusterIP
# plus the apiserver's real endpoint IPs (the control-plane nodes). Both fall
# inside the blocked_egress_cidrs ranges (10.0.0.0/8 and 192.168.0.0/16), so
# pods that need the API server require explicit carve-out rules. Calico
# evaluates egress policy post-DNAT, so the ENDPOINT IP is what must be allowed
# -- track it dynamically so a control-plane IP change doesn't silently break
# consumers. Only read when the flag is on; callers that don't set
# allow_to_k8sapi never perform this lookup.
data "kubernetes_endpoints_v1" "kubernetes" {
  count = var.allow_to_k8sapi ? 1 : 0

  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}
