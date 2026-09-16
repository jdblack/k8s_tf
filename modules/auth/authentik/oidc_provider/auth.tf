
# OIDC signing key, OWNED here instead of looked up by name.
#
# This was `data "authentik_certificate_key_pair" "cert" { name = "tls" }` -- an object
# authentik's cert-discovery task imports out of /certs (where the chart mounts the TLS
# secret) and stamps `managed: goauthentik.io/crypto/discovered/...`. Through 2025.10 it
# named those after the FILE (tls.crt -> "tls"); 2026.8 added tls.crt/tls.key to its
# parent-DIRECTORY branch and renames matches in place, so bumping the chart alone renamed
# the object to "auth.vn.linuxguru.net" and broke every `mantle` plan. That name is
# upstream's to change, and the coupling also rotated our token signing with every
# cert-manager web-cert renewal (the kid derives from the private key). So: own it.
#
# Generated here, so the key matches nothing in /certs and discovery never touches it.
resource "tls_private_key" "signing" {
  algorithm = "RSA" # matches the RSA key this replaces; widest client support
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "signing" {
  private_key_pem = tls_private_key.signing.private_key_pem
  subject {
    common_name = "${var.name} OIDC signing"
  }
  # Signs tokens, never presented over TLS: nothing renews, validates, or chains it.
  validity_period_hours = 87600 # 10y
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

# Groups claim. authentik ships no 'groups' scope mapping in this instance, so create
# one. Each client gets its own mapping object (same scope_name, unique name) -- a
# provider only references its own, so the token still carries exactly one groups
# claim; the duplication is cosmetic, in authentik's UI.
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
  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = var.redirect_uri
      # Declared because the API stores it and the provider reads it back: leaving it out
      # makes 2026.8.0's provider plan a perpetual no-op removal of this one key
      # (`- "redirect_uri_type" = "authorization"`) that never converges, which would show
      # as permanent drift in every mantle plan.
      redirect_uri_type = "authorization"
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

