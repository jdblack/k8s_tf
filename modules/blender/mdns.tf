# Bonjour/mDNS advertiser for the Samba share (Finder's "Network" lists mDNS-SD only). hostNetwork is
# required: mDNS is link-local multicast a pod netns cannot put on the LAN. Advertiser only -- the SMB
# data path is untouched.
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
    # >1 advertiser contests the Bonjour instance name and macOS renames it.
    replicas = 1

    selector {
      match_labels = { app = local.mdns_name }
    }

    template {
      metadata {
        # NOT the samba Service's selector label: the hostNetwork pod would add a <node-ip>:445
        # endpoint with nothing listening.
        labels = { app = local.mdns_name }

        # subPath ConfigMaps never refresh in place, so force a restart on change.
        annotations = {
          "checksum/config" = sha256(jsonencode(kubernetes_config_map_v1.mdns[0].data))
        }
      }

      spec {
        host_network = true
        # hostNetwork pods ignore ClusterFirst and would use the node's resolv.conf.
        dns_policy = "ClusterFirstWithHostNet"

        automount_service_account_token = false

        node_selector = var.mdns_node_selector

        container {
          name  = local.mdns_name
          image = var.mdns_image

          # ENABLE_DBUS=no (none in the image; avahi exits without a bus), PUBLISH_WORKSTATION=no (else
          # the node shows as a phantom Mac), DISALLOW_OTHER_STACKS=yes (fail loudly rather than duel
          # mDNS on the node).
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

          # Starts as root on purpose (the daemon chroots itself); the NET_RAW drop is the point, since
          # it would otherwise allow LAN sniffing/spoofing.
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

          # Whole dir, not single files: hides the image's bundled ssh/sftp services.
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
