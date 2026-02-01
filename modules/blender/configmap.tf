resource "kubernetes_config_map_v1" "samba_config" {
  metadata {
    name      = "${local.samba_name}-config"
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
  }

  data = {
    "smb.conf" = templatefile("${path.module}/smb.conf", {})
  }
}
