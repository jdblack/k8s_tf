locals {
  outpost_labels = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }

  core_url = "http://authentik-server.${var.core_namespace}.svc.cluster.local:80"

  browser_url = "https://${coalesce(var.auth_fqdn, "auth.${var.domain}")}"
}

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_proxy" "app" {
  for_each = var.apps

  name               = each.key
  mode               = "proxy"
  external_host      = each.value.external_host
  internal_host      = each.value.internal_host
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id
}

resource "authentik_application" "app" {
  for_each = var.apps

  name              = each.key
  slug              = each.key
  protocol_provider = authentik_provider_proxy.app[each.key].id
  meta_launch_url   = each.value.external_host
  meta_icon         = each.value.icon
  open_in_new_tab   = true
}

resource "authentik_group" "access" {
  name = var.group_name
}

resource "authentik_policy_binding" "app" {
  for_each = var.apps

  target = authentik_application.app[each.key].uuid
  group  = authentik_group.access.id
  order  = 0
}

resource "authentik_outpost" "outpost" {
  name               = var.outpost_name
  type               = "proxy"
  protocol_providers = [for p in authentik_provider_proxy.app : p.id]
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
