
resource "kubernetes_deployment_v1" "samba" {
  metadata {
    name      = local.samba_name
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.samba_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.samba_name
        }
      }

      spec {
        container {
          name  = local.samba_name
          image = "dockurr/samba"

          env {
            name  = "NAME"
            value = var.name
          }
          env {
            name = "USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.samba.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.samba.metadata[0].name
                key  = "password"
              }
            }
          }

          port {
            container_port = 445
          }

          volume_mount {
            name       = "storage"
            mount_path = "/storage"
            read_only  = false
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/samba/smb.conf"
            sub_path   = "smb.conf"
          }
        }

        volume {
          name = "storage"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.samba.metadata[0].name
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map_v1.samba_config.metadata[0].name
          }
        }
      }
    }
  }
}
