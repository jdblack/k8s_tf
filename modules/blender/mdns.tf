resource "kubernetes_config_map_v1" "mdns" {
  count = var.mdns_enabled ? 1 : 0

  metadata {
    name      = local.mdns_name
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
  }

  data = {
    "${var.name}.service" = templatefile("${path.module}/mdns.service", {
      host = local.samba_host
    })

    "hosts" = local.samba_vip == "" ? "" : "${local.samba_vip} ${local.samba_host}\n"
  }
}

resource "kubernetes_deployment_v1" "mdns" {
  count = var.mdns_enabled ? 1 : 0

  metadata {
    name      = local.mdns_name
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
    labels    = { app = local.mdns_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = local.mdns_name }
    }

    template {
      metadata {
        labels = { app = local.mdns_name }

        annotations = {
          "checksum/config" = sha256(jsonencode(kubernetes_config_map_v1.mdns[0].data))
        }
      }

      spec {
        host_network = true
        dns_policy   = "ClusterFirstWithHostNet"

        automount_service_account_token = false

        node_selector = var.mdns_node_selector

        container {
          name  = local.mdns_name
          image = var.mdns_image

          env {
            name  = "SERVER_HOST_NAME"
            value = local.mdns_name
          }
          env {
            name  = "SERVER_DOMAIN_NAME"
            value = "local"
          }
          env {
            name  = "SERVER_USE_IPV4"
            value = "yes"
          }
          env {
            name  = "SERVER_USE_IPV6"
            value = "no"
          }
          env {
            name  = "SERVER_DISALLOW_OTHER_STACKS"
            value = "yes"
          }
          env {
            name  = "SERVER_ENABLE_DBUS"
            value = "no"
          }
          env {
            name  = "PUBLISH_PUBLISH_ADDRESSES"
            value = "no"
          }
          env {
            name  = "PUBLISH_PUBLISH_HINFO"
            value = "no"
          }
          env {
            name  = "PUBLISH_PUBLISH_WORKSTATION"
            value = "no"
          }

          security_context {
            capabilities {
              drop = ["NET_RAW"]
            }
          }

          resources {
            requests = {
              cpu    = "5m"
              memory = "16Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }

          volume_mount {
            name       = "services"
            mount_path = "/etc/avahi/services"
            read_only  = true
          }

          volume_mount {
            name       = "hosts"
            mount_path = "/etc/avahi/hosts"
            sub_path   = "hosts"
            read_only  = true
          }
        }

        volume {
          name = "services"

          config_map {
            name = kubernetes_config_map_v1.mdns[0].metadata[0].name

            items {
              key  = "${var.name}.service"
              path = "${var.name}.service"
            }
          }
        }

        volume {
          name = "hosts"

          config_map {
            name = kubernetes_config_map_v1.mdns[0].metadata[0].name

            items {
              key  = "hosts"
              path = "hosts"
            }
          }
        }
      }
    }
  }
}
