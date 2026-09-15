locals {
  plex_host_internal = "${var.plex_name}.${var.domain}"
  helm_values = {
    extraEnv = {
      PLEX_CLAIM = var.plex_claim
      PLEX_UID   = 1000
      PLEX_GID   = 1000
    }
    pms = {
      configStorage = "30Gi"
    }
    image = {
      tag        = "latest"
      pullPolicy = "Always"
    }
    extraVolumes = [
      {
        name = "media"
        persistentVolumeClaim = {
          claimName = var.movies_pvc
        }
      }
    ]
    extraVolumeMounts = [
      {
        name      = "media"
        mountPath = "/media"
      }
    ]
    ingress = {
      # Web UI exposure is the shared public gateway (listener.tf); the chart keeps only
      # the LoadBalancer service for direct PMS access (32400).
      enabled = false
    }
    service = {
      type = "LoadBalancer"
      # Required for the direct PMS LoadBalancer to survive the media ingress firewall:
      # with the default (Cluster), kube-proxy SNATs cross-node traffic to a
      # cluster-internal IP that no external CIDR in allowed_ingress_cidrs matches.
      # Local preserves the real client source IP (MetalLB re-announces the VIP to nodes
      # actually running the pod).
      externalTrafficPolicy = "Local"
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal,
      }
    }
  }
}