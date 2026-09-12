
data "authentik_certificate_key_pair" "cert" {
  name = "tls"
}


data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-provider-invalidation-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_property_mapping_provider_scope" "email" {
  scope_name = "email"
}

data "authentik_property_mapping_provider_scope" "profile" {
  scope_name = "profile"
}
data "authentik_property_mapping_provider_scope" "openid" {
  scope_name = "openid"
}

# Groups claim. authentik does not ship a 'groups' scope mapping in this
# instance (the provider scope mappings present are only openid/email/profile/
# offline_access/entitlements/ak_proxy/goauthentik.io/api), so create one.
#
# Each client gets its own mapping object (same scope_name, unique name). A
# provider only ever references its own, so the emitted token still carries
# exactly one groups claim -- the duplication is cosmetic, in authentik's UI.
resource "authentik_property_mapping_provider_scope" "groups" {
  name        = "OpenID 'groups' (${var.name})"
  scope_name  = "groups"
  description = "Groups claim for ${var.name}"
  expression  = <<-EOT
    return {
        "groups": [group.name for group in request.user.ak_groups.all()],
    }
  EOT
}


resource "authentik_provider_oauth2" "oauth2" {
  name               = var.name
  client_id          = var.name
  invalidation_flow  = data.authentik_flow.default-provider-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.cert.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]

  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = var.redirect_uri
    }
  ]

}

resource "authentik_group" "admin" {
  name = "${var.name}-admin"
}

resource "authentik_group" "user" {
  name = "${var.name}-user"
}

resource "authentik_application" "app" {
  name              = var.name
  slug              = var.name
  protocol_provider = authentik_provider_oauth2.oauth2.id
  meta_icon         = var.meta_icon
  open_in_new_tab   = var.open_in_new_tab
}

