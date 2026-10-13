resource "kubernetes_namespace_v1" "home" {
  metadata {
    name   = var.namespace
    labels = local.labels

    annotations = {
      "cline-home/note" = "Cline's sandbox. Standing Go! inside. Break things on purpose; don't get James arrested."
    }
  }
}
