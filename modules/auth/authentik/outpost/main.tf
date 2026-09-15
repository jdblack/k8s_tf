# Manual outpost deployment: authentik chart 2025.10.x no longer embeds proxy outposts.
# Terraform owns the pods so a rebuild stays tofu-driven and the namespace's egress
# firewall applies like any other pod.
#
# Runs alongside the protected apps, so the gateway data plane and those apps are both
# reached same-namespace; only core (kube-auth) is cross-namespace, allowed at the bottom.
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

# Egress carve-out for the outpost only. The Service is authentik-server:80 but Calico
# evaluates egress post-DNAT, so the allow targets the pod's real HTTP port (9000).
# Additive to the namespace-wide firewall.
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
