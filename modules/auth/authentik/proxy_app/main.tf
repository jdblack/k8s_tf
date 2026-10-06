locals {
  icon_cdn      = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"
  external_host = "https://${coalesce(var.hostname, "${var.name}.${var.domain}")}"
  service       = coalesce(var.service, var.name)
  icon          = var.icon == null ? "${local.icon_cdn}/${var.name}.svg" : (var.icon == "" ? null : var.icon)
  group_prefix  = coalesce(var.group_prefix, var.name)
}

data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_proxy" "app" {
  name               = var.name
  mode               = "proxy"
  external_host      = local.external_host
  internal_host      = "http://${local.service}.${var.namespace}.svc.cluster.local:${var.port}"
  authorization_flow = data.authentik_flow.authorization.id
  invalidation_flow  = data.authentik_flow.invalidation.id

  # Without this the session dies 10m after a tab goes idle: the cookie expires, so
  # the next request (a UI's websocket/reconnect call, which cannot follow the login
  # redirect) lands in the auth flow and the app shows "connection lost" until reload.
  access_token_validity = var.access_token_validity
}

resource "authentik_application" "app" {
  name              = var.name
  slug              = var.name
  protocol_provider = authentik_provider_proxy.app.id
  meta_launch_url   = local.external_host
  meta_icon         = local.icon
  open_in_new_tab   = true
}

resource "authentik_outpost_provider_attachment" "app" {
  count = var.attach ? 1 : 0

  outpost           = var.outpost_id
  protocol_provider = authentik_provider_proxy.app.id
}

resource "authentik_group" "admin" {
  name = "${local.group_prefix}-admin"
}

resource "authentik_group" "user" {
  name = "${local.group_prefix}-user"
}

# Both, as with the OIDC apps, so an admin need not also join -user to sign in.
resource "authentik_policy_binding" "own_groups" {
  for_each = var.bind ? {
    admin = authentik_group.admin.id
    user  = authentik_group.user.id
  } : {}

  target = authentik_application.app.uuid
  group  = each.value
  order  = 0
}
