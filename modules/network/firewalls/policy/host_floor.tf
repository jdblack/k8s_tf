# Companion to the k8s NetworkPolicy: admits the node host endpoints by identity, so the
# per-node ip_blocks drop out. Namespaced and additive -- the namespace is already default-deny
# ingress, and local.calico_selector matches exactly the same pods the k8s policy governs.
resource "kubectl_manifest" "host_floor" {
  count = var.direction == "ingress" && var.host_identity ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "projectcalico.org/v3"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "${var.name}-host-floor"
      namespace = var.namespace
    }
    spec = {
      selector = local.calico_selector
      types    = ["Ingress"]
      ingress = [{
        action = "Allow"
        # global() is required: a namespaced policy's selector is namespace-scoped by default, so
        # without it the selector cannot see the cluster-scoped host endpoints.
        source = {
          namespaceSelector = "global()"
          selector          = "projectcalico.org/created-by == 'calico-kube-controllers'"
        }
      }]
    }
  })
}
