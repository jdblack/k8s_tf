resource kubernetes_service_v1 samba {
  metadata {
    name      = local.samba_name
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname" = "samba-${var.name}.${var.domain}"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = local.samba_name
    }

    port {
      port        = 445
      target_port = 445
      protocol    = "TCP"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}
