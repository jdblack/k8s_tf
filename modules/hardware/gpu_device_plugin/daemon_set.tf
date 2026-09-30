# Translation of upstream intel-device-plugins-for-kubernetes deployments/gpu_plugin/base:
# bump image_tag in a commit of its own so the plugin version stays visible in history.
resource "kubernetes_daemon_set_v1" "plugin" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector {
      match_labels = local.labels
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        node_selector = var.node_selector

        container {
          name              = var.name
          image             = "${var.image_repository}:${var.image_tag}"
          args              = ["-shared-dev-num=${var.shared_dev_num}"]
          image_pull_policy = "IfNotPresent"

          env {
            name = "NODE_NAME"

            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "HOST_IP"

            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          resources {
            requests = {
              cpu    = "40m"
              memory = "45Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "115Mi"
            }
          }

          security_context {
            read_only_root_filesystem  = true
            allow_privilege_escalation = false

            se_linux_options {
              type = "container_device_plugin_t"
            }

            capabilities {
              drop = ["ALL"]
            }

            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          volume_mount {
            name       = "devfs"
            mount_path = "/dev/dri"
            read_only  = true
          }

          volume_mount {
            name       = "sysfsdrm"
            mount_path = "/sys/class/drm"
            read_only  = true
          }

          # Kubelet discovers the plugin's socket here, and reads the CDI specs the plugin
          # writes into /var/run/cdi (containerd's enable_cdi is a host prerequisite).
          volume_mount {
            name       = "kubeletsockets"
            mount_path = "/var/lib/kubelet/device-plugins"
          }

          volume_mount {
            name       = "cdipath"
            mount_path = "/var/run/cdi"
          }
        }

        volume {
          name = "devfs"

          host_path {
            path = "/dev/dri"
          }
        }

        volume {
          name = "sysfsdrm"

          host_path {
            path = "/sys/class/drm"
          }
        }

        volume {
          name = "kubeletsockets"

          host_path {
            path = "/var/lib/kubelet/device-plugins"
          }
        }

        volume {
          name = "cdipath"

          host_path {
            path = "/var/run/cdi"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}
