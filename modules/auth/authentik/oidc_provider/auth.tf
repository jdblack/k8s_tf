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

# Looked up by managed slug, not scope_name: a provider that overrides the email
# scope (see email_verified below) adds a second mapping with scope_name "email",
# which would make a scope_name lookup ambiguous.
data "authentik_property_mapping_provider_scope" "email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_property_mapping_provider_scope" "openid" {
  scope_name = "openid"
}

# Built in, and the only thing that makes authentik mint a refresh token; without it a
# client can renew only through the browser's silent-redirect iframe, which cookies block.
data "authentik_property_mapping_provider_scope" "offline_access" {
  scope_name = "offline_access"
}

resource "authentik_property_mapping_provider_scope" "groups" {
  name        = "OpenID 'groups' (${var.name})"
  scope_name  = "groups"
  description = "Groups claim for ${var.name}"

  # all_groups, not ak_groups: a user granted through the `admin`/`user` tier is only a
  # direct member of that group -- nesting lives in the parents -- and oCIS/pastebin map the
  # role off <app>-admin/<app>-user, which ak_groups would omit.
  expression = <<-EOT
    return {
        "groups": [group.name for group in request.user.all_groups()],
    }
  EOT
}

# The built-in email mapping hardcodes email_verified: false, and clients that gate
# sign-in on the claim (pingvin-share) refuse a false outright. This replaces it for
# providers that ask for it; the identity source here is authentik, so the address is
# authoritative.
resource "authentik_property_mapping_provider_scope" "email_verified" {
  count = var.email_verified ? 1 : 0

  name        = "OpenID 'email' verified (${var.name})"
  scope_name  = "email"
  description = "Email claim for ${var.name}, asserted verified"
  expression  = <<-EOT
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOT
}

# The built-in profile mapping hardcodes groups to direct memberships, and the official
# clients ask only for `profile` -- never `groups` -- so this claim, not the `groups`
# mapping above, is what oCIS maps roles off. Built-in's claims, nesting restored.
resource "authentik_property_mapping_provider_scope" "profile" {
  name        = "OpenID 'profile' (${var.name})"
  scope_name  = "profile"
  description = "Profile claim for ${var.name}, with nested groups"

  expression = <<-EOT
    return delete_none_values({
        "name": request.user.name,
        "given_name": ak_obj_attr(request.user, "given_name", "name"),
        "family_name": ak_obj_attr(request.user, "family_name"),
        "preferred_username": request.user.username,
        "nickname": request.user.username,
        "groups": [group.name for group in request.user.all_groups()],
        "picture": request.user.avatar,
    })
  EOT
}

resource "authentik_provider_oauth2" "oauth2" {
  name               = var.name
  client_id          = coalesce(var.client_id, var.name)
  invalidation_flow  = data.authentik_flow.default-provider-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = authentik_certificate_key_pair.signing.id
  client_type        = var.client_type

  access_token_validity  = var.access_token_validity
  refresh_token_validity = var.refresh_token_validity

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
    var.email_verified ? authentik_property_mapping_provider_scope.email_verified[0].id : data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.offline_access.id,
    authentik_property_mapping_provider_scope.profile.id,
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
    [
      for uri in var.regex_redirect_uris : {
        matching_mode     = "regex"
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
