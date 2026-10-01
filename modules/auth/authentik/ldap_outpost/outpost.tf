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

# Key is the one the oCIS chart reads out of secretRefs.ldapSecretRef.
resource "kubernetes_secret_v1" "bind" {
  metadata {
    name      = "${var.service_name}-bind"
    namespace = var.namespace
    labels    = local.outpost_labels
  }

  data = {
    "reva-ldap-bind-password" = random_password.bind_password.result
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
          name  = "ldap"
          image = "${var.image}:${var.image_tag}"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.api.metadata[0].name
            }
          }

          port {
            name           = "ldap"
            container_port = var.ldap_port
          }
          port {
            name           = "ldaps"
            container_port = var.ldaps_port
          }
          port {
            name           = "metrics"
            container_port = var.metrics_port
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
      name        = "ldap"
      port        = var.ldap_port
      target_port = "ldap"
    }
    port {
      name        = "ldaps"
      port        = var.ldaps_port
      target_port = "ldaps"
    }
    port {
      name        = "metrics"
      port        = var.metrics_port
      target_port = "metrics"
    }
  }
}
