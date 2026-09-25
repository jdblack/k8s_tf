locals {
  outpost_labels = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }

  core_url = "http://authentik-server.${var.core_namespace}.svc.cluster.local:80"

  browser_url = "https://${coalesce(var.auth_fqdn, "auth.${var.domain}")}"
}

resource "authentik_group" "access" {
  name = var.group_name
}

resource "authentik_outpost" "outpost" {
  name = var.outpost_name
  type = "proxy"

  # Empty on purpose for callers that attach providers afterwards; authentik only
  # accepts an empty list on update, never on create.
  protocol_providers = var.provider_ids

  lifecycle {
    ignore_changes = [protocol_providers]
  }
}

data "authentik_user" "outpost_sa" {
  username = "ak-outpost-${replace(authentik_outpost.outpost.id, "-", "")}"
}

resource "authentik_token" "outpost" {
  identifier   = "${var.outpost_name}-tf"
  user         = data.authentik_user.outpost_sa.pk
  intent       = "api"
  expiring     = false
  retrieve_key = true
}

resource "kubernetes_secret_v1" "api" {
  metadata {
    name      = "${var.service_name}-api"
    namespace = var.namespace
    labels    = local.outpost_labels
  }

  data = {
    AUTHENTIK_HOST         = local.core_url
    AUTHENTIK_HOST_BROWSER = local.browser_url
    AUTHENTIK_TOKEN        = authentik_token.outpost.key
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

        # The outpost hands its boot-time session store to every refreshed app, so a
        # provider Validity change only takes effect on a restart.
        annotations = {
          "checksum/session-validity" = sha256(var.session_validity)
        }
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
            container_port = var.http_port
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
      port        = var.http_port
      target_port = "http"
    }
    port {
      name        = "https"
      port        = 9443
      target_port = "https"
    }
  }
}
