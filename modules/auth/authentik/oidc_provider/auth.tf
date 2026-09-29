resource "tls_private_key" "signing" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "signing" {
  private_key_pem = tls_private_key.signing.private_key_pem
  subject {
    common_name = "${var.name} OIDC signing"
  }
  validity_period_hours = 87600
  allowed_uses          = ["digital_signature"]
}

resource "authentik_certificate_key_pair" "signing" {
  name             = "${var.name}-signing"
  certificate_data = tls_self_signed_cert.signing.cert_pem
  key_data         = tls_private_key.signing.private_key_pem
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
  signing_key        = authentik_certificate_key_pair.signing.id

  # An omitted grant list is empty in authentik 2026.x, which rejects every flow, authorization_code
  # included; these are the grants the providers created before that default have.
  grant_types = [
    "authorization_code",
    "hybrid",
    "implicit",
    "client_credentials",
    "password",
    "urn:ietf:params:oauth:grant-type:device_code",
    "refresh_token",
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]

  allowed_redirect_uris = concat(
    [
      {
        matching_mode     = "strict"
        url               = var.redirect_uri
        redirect_uri_type = "authorization"
      }
    ],
    [
      for uri in var.extra_redirect_uris : {
        matching_mode     = "strict"
        url               = uri
        redirect_uri_type = "authorization"
      }
    ],
  )

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
  meta_launch_url   = var.meta_launch_url
  open_in_new_tab   = var.open_in_new_tab
}

resource "authentik_policy_binding" "app" {
  count  = var.group_id == null ? 0 : 1
  target = authentik_application.app.uuid
  group  = var.group_id
  order  = 0
}

# Both own groups, not just -user: an admin has to be able to log in, and binding -user
# alone would force every admin into a second group purely to authenticate.
resource "authentik_policy_binding" "own_groups" {
  for_each = var.bind_app ? {
    admin = authentik_group.admin.id
    user  = authentik_group.user.id
  } : {}

  target = authentik_application.app.uuid
  group  = each.value
  order  = 0
}
