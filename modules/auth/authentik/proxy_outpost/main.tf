# The proxy-outpost pattern for apps that speak no OIDC/SAML, in one module: the authentik
# side (proxy provider + application + access group + outpost + the outpost's API token)
# and the Kubernetes side (Secret + Deployment + Service) in the namespace being protected.
#
# The gateway routes the public host to the OUTPOST, not to the app: the outpost
# authenticates the user against core, injects X-authentik-* headers, then reverse-proxies
# to the app's Service.
#
#   browser -> <app>.<domain> (TLS at the gateway)
#            -> <service_name>:9000 (no session = 302 to the authentik login)
#            -> <app>:<port>
#
# The app's own login must then be neutralised or the user gets prompted twice: the *arr
# apps run AuthenticationMethod = External; qBittorrent instead whitelists the pod CIDR.
# Both are one-time, hand-run steps -- see the main README.
#
# One module rather than two: the halves are always one call site and share outpost_name /
# service_name, and the outpost's API token must not cross a module boundary.
locals {
  outpost_labels = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }

  # Core's server Service (chart release "authentik" -> "authentik-server"; namespace from
  # stacks/core/auth.tf). In-cluster only, so plain HTTP is fine -- never seen by a browser.
  core_url = "http://authentik-server.${var.core_namespace}.svc.cluster.local:80"

  # Browser-facing redirects during the OAuth dance. If this were empty the outpost would
  # fall back to core_url, leaking the internal service name into redirects, so it is
  # always set. Mirrors core's `local.fqdn`, which stacks/core/auth.tf pins to auth.<domain>.
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

# No `count`: members are managed by hand in the UI, so a destroy/recreate drops them.
resource "authentik_group" "access" {
  name = var.group_name
}

resource "authentik_policy_binding" "app" {
  for_each = var.apps

  # target wants the application's UUID -- .id is the slug.
  target = authentik_application.app[each.key].uuid
  group  = authentik_group.access.id
  order  = 0
}

resource "authentik_outpost" "outpost" {
  name               = var.outpost_name
  type               = "proxy"
  protocol_providers = [for p in authentik_provider_proxy.app : p.id]
}

# authentik auto-creates a service account ak-outpost-<uuid-without-hyphens> but does not
# expose its token key, so mint our own non-expiring API token for it and hand that to the
# Deployment as AUTHENTIK_TOKEN.
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

# Terraform-owned pods, because authentik chart 2025.10.x no longer embeds proxy outposts.
# That also keeps a from-scratch rebuild tofu-driven.
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

# This is what the app's HTTPRoute points at.
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

