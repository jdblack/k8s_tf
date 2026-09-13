# Bonjour/mDNS advertisement for the Samba share.
#
# This is what makes the share appear in Finder on macOS. Finder's "Shared" and
# "Network" views are populated by mDNS-SD discovery *only* -- a working unicast
# name (external-dns already publishes samba-blender.<domain>, and it resolves
# and connects fine) can never put an entry there, and macOS has no NetBIOS/WSD
# browsing left to fall back on.
#
# Nothing in the cluster advertised it before: dockurr/samba runs `smbd` alone
# (no avahi-daemon, no nmbd, no 5353 socket -- verified on the live pod), so the
# LAN never saw an _smb._tcp record.
#
# Why hostNetwork: mDNS is link-local multicast on 224.0.0.251:5353. A pod in
# the Calico netns cannot put that on the physical LAN, so the advertiser has to
# share the node's network namespace. Verified both ways: same config in a pod
# netns is invisible to the LAN; with hostNetwork the Mac sees the records
# immediately (dns-sd -B _smb._tcp local, on the en0 interface).
#
# The records it publishes, for the share behind samba-blender.<domain>:445:
#   _smb._tcp          the discovery record Finder keys off
#   _device-info._tcp  the icon (model=MacSamba, matching fruit:model)
#   a static A record  so the SRV target resolves inside mDNS too, rather than
#                      depending on the client's unicast lookup succeeding
#
# It is an advertiser only: it never serves SMB, and the data path is unchanged
# (VIP -> Service -> pod, externalTrafficPolicy: Cluster).
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

    # avahi's static host list. Empty is valid (the daemon just publishes no
    # address records) and is what happens on a fresh cluster before MetalLB
    # hands the Service an IP.
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
    # Never more than one: a second advertiser means two hosts claiming the same
    # Bonjour instance name, and macOS starts renaming things ("Blender (2)").
    replicas = 1

    selector {
      match_labels = { app = local.mdns_name }
    }

    template {
      metadata {
        # Deliberately NOT the samba Service's selector label. This pod is
        # hostNetwork, so if it matched `app = blender-samba` its "pod IP" would
        # be the node's address and the SMB Service would gain a
        # <node-ip>:445 endpoint with nothing listening on it -- kube-proxy
        # would then blackhole about half of all new SMB connections.
        labels = { app = local.mdns_name }

        # Roll the pod when the advertised records change. A subPath-mounted
        # ConfigMap is never refreshed in place, and Kubernetes does not restart
        # pods for a ConfigMap edit -- so without this a VIP change would leave
        # the pod advertising the old address until something restarted it.
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

          # flungo/avahi renders avahi-daemon.conf from these. Three of them are
          # load-bearing:
          #   ENABLE_DBUS=no          the image ships no dbus-daemon, and avahi
          #                           0.9 exits outright if it cannot reach a bus
          #   PUBLISH_WORKSTATION=no  otherwise the node shows up as a phantom
          #                           Mac in everyone's sidebar
          #   DISALLOW_OTHER_STACKS   fail loudly instead of duelling with any
          #                           mDNS stack a node might already run
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

          # The daemon chroots and drops to the unprivileged `avahi` user itself,
          # so it has to start as root by design -- don't add runAsNonRoot here.
          # NET_RAW is the one capability worth removing: it is what would let a
          # compromised advertiser sniff or spoof on the node's LAN segment.
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

          # Mounting the whole directory (not a single file) hides the image's
          # bundled ssh.service / sftp-ssh.service, which would otherwise
          # advertise the node itself as an SSH box on the LAN.
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
