# Manual outpost deployment (authentik chart 2025.10.x no longer embeds proxy
# outposts; managed/embedded outposts are disabled in this release). Terraform
# owns the pods so rebuild-from-scratch stays tofu-driven and the media
# namespace's egress firewall applies to the outpost like every other pod.
#
# The deployment runs in the namespace that hosts the protected apps (media):
# the media gateway's data plane reaches the outpost same-namespace, and the
# outpost reaches the apps same-namespace. Its only cross-namespace traffic is
# to authentik core (kube-auth), which the NetworkPolicy at the bottom of this
# file allows -- everything else stays default-deny via the media firewall.
locals {
  outpost_labels = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }
}

resource "kubernetes_secret_v1" "api" {
  metadata {
    name      = "${var.service_name}-api"
    namespace = var.namespace
    labels    = local.outpost_labels
  }

  data = {
    AUTHENTIK_HOST         = var.core_url
    AUTHENTIK_HOST_BROWSER = var.browser_url
    AUTHENTIK_TOKEN        = var.token
  }
}

resource "kubernetes_deployment_v1" "outpost" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels    = local.outpost_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.outpost_labels
    }

    template {
      metadata {
        labels = local.outpost_labels
      }

      spec {
        container {
          name  = "proxy"
          image = "${var.image}:${var.image_tag}"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.api.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = 9000
          }
          port {
            name           = "https"
            container_port = 9443
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "outpost" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels    = local.outpost_labels
  }

  spec {
    type = "ClusterIP"

    selector = local.outpost_labels

    port {
      name        = "http"
      port        = 9000
      target_port = "http"
    }
    port {
      name        = "https"
      port        = 9443
      target_port = "https"
    }
  }
}

# Egress carve-out for the outpost only: reach authentik core (kube-auth
# server/worker). The service is `authentik-server:80` but Calico evaluates
# egress post-DNAT, so the allow targets the pod's real HTTP listen port
# (9000). Additive to the namespace-wide media firewall. Rendered via the
# shared policy module so it matches the rest of the firewall library.
module "core_egress" {
  source       = "../../../network/firewalls/policy"
  name         = "authentik-outpost-core"
  namespace    = var.namespace
  pod_selector = local.outpost_labels
  policy_types = ["Egress"]

  egress_rules = [{
    peers = [{
      namespace_selector = { "kubernetes.io/metadata.name" = var.core_namespace }
      pod_selector       = { "app.kubernetes.io/name" = "authentik" }
    }]
    ports = [{ protocol = "TCP", port = 9000 }]
  }]
}

moved {
  from = kubernetes_network_policy_v1.core_egress
  to   = module.core_egress.kubernetes_network_policy_v1.this
}
