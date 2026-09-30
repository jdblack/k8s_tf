resource "kubernetes_namespace_v1" "kube_hardware" {
  metadata {
    name = var.namespace
    labels = {
      # Device plugins read the host through hostPath, which Pod Security admission only
      # admits in a privileged namespace.
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}
