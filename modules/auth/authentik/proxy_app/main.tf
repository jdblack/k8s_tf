# Reverse-proxy providers for apps with no OIDC/SAML: the outpost authenticates, then
# proxies, so the gateway routes the public host to the outpost, not the app.
#
# Each application is bound to one group; no binding, no access. Membership is hand-managed
# in the authentik UI (TF owns structure, the UI owns people).

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
# deployment as AUTHENTIK_TOKEN.
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
