# Reverse-proxy ("single application") providers for apps that don't speak
# OIDC/SAML natively (the *arr stack, whisker, the SeaweedFS admin UI). The outpost
# authenticates the user then proxies to the app's internal service, so the gateway
# routes the public hostname to the outpost instead of the app.
#
# Access control: each application is bound to a single group (var.group_name) via
# authentik_policy_binding. No bindings, no access -- group membership is managed by
# hand in the authentik UI (TF owns structure, UI owns people). To grant a future
# app to this group, add an entry to var.apps and re-apply.
#
# The outpost service account + token created here are consumed by the companion
# modules/auth/authentik/outpost Kubernetes deployment.

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

# The group resource briefly carried a `count`; move the indexed instances back to
# the plain address so media/whisker keep their existing groups instead of
# destroy/recreating them (which would drop the UI-managed memberships).
moved {
  from = authentik_group.access[0]
  to   = authentik_group.access
}

resource "authentik_policy_binding" "app" {
  for_each = var.apps

  # target expects the application's UUID -- .id is the slug.
  target = authentik_application.app[each.key].uuid
  group  = authentik_group.access.id
  order  = 0
}

resource "authentik_outpost" "outpost" {
  name               = var.outpost_name
  type               = "proxy"
  protocol_providers = [for p in authentik_provider_proxy.app : p.id]
}

# authentik auto-creates a per-outpost service account named
# ak-outpost-<uuid-without-hyphens>. The provider does not expose the
# auto-generated token key, so mint our own non-expiring API token for that
# service account and hand it to the Kubernetes deployment as AUTHENTIK_TOKEN.
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
