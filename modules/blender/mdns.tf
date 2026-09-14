# Bonjour/mDNS advertisement for the Samba share, so it appears in Finder's
# "Shared"/"Network" view -- macOS populates those from mDNS-SD only; the
# unicast name external-dns publishes can never put an entry there.
#
# hostNetwork is required: mDNS is link-local multicast (224.0.0.251:5353),
# which a pod netns cannot put on the physical LAN (verified both ways).
# Inside, dockurr/samba runs `smbd` alone -- no avahi, no nmbd -- so nothing
# advertised it before. Publishes _smb._tcp (discovery), _device-info._tcp
# (icon) and a static A record so the SRV target resolves. Advertiser only: it
# never serves SMB; the data path (VIP -> Service -> pod) is unchanged.
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

    # avahi's static host list. Empty is valid and is what happens on a fresh
    # cluster before MetalLB hands the Service an IP.
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
    # Never more than one: two advertisers claim the same Bonjour instance
    # name and macOS renames things ("Blender (2)").
    replicas = 1

    selector {
      match_labels = { app = local.mdns_name }
    }

    template {
      metadata {
        # Deliberately NOT the samba Service's selector label: this pod is
        # hostNetwork, so matching it would give the SMB Service a
        # <node-ip>:445 endpoint with nothing listening -- kube-proxy would then
        # blackhole about half of all new SMB connections.
        labels = { app = local.mdns_name }

        # Roll the pod when the advertised records change: a subPath-mounted
        # ConfigMap is never refreshed in place and k8s does not restart pods
        # for a ConfigMap edit, so a VIP change would otherwise be ignored.
        # (Same pattern as modules/vaultwarden.)
        annotations = {
          "checksum/config" = sha256(jsonencode(kubernetes_config_map_v1.mdns[0].data))
        }
      }

      spec {
        host_network = true
        # hostNetwork pods silently ignore ClusterFirst and use the node's
        # resolv.conf; this keeps the behaviour deliberate (it needs neither,
        # but be explicit rather than surprising).
        dns_policy = "ClusterFirstWithHostNet"

        # No API access: it advertises on the LAN and talks to nothing else.
        automount_service_account_token = false

        node_selector = var.mdns_node_selector

        container {
          name  = local.mdns_name
          image = var.mdns_image

          # flungo/avahi renders avahi-daemon.conf from these. Three are
          # load-bearing: ENABLE_DBUS=no (no dbus in the image; avahi 0.9 exits
          # without a bus), PUBLISH_WORKSTATION=no (else the node shows up as a
          # phantom Mac in everyone's sidebar), DISALLOW_OTHER_STACKS (fail
          # loudly rather than duel any mDNS stack already on the node).
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

          # The daemon chroots and drops to `avahi` itself, so it must start as
          # root -- don't add runAsNonRoot. Dropping NET_RAW is the point: it is
          # what would let a compromised advertiser sniff/spoof on the LAN.
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

          # Mounting the whole directory (not single files) hides the image's
          # bundled ssh.service / sftp-ssh.service, which would advertise the
          # node itself as an SSH box on the LAN.
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
