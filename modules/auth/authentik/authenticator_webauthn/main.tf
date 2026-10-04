locals {
  slug  = coalesce(var.slug, var.name)
  title = coalesce(var.title, "Set up ${var.friendly_name}")
}

resource "authentik_flow" "setup" {
  name           = local.slug
  slug           = local.slug
  title          = local.title
  designation    = "stage_configuration"
  authentication = var.authentication
}

# configure_flow is what lists the stage under user settings' MFA devices, so enrollment
# is self-service rather than an admin pushing a flow at each user. Flows are addressed by
# uuid, not id: for this resource `id` is the slug, which the API rejects as a reference.
resource "authentik_stage_authenticator_webauthn" "setup" {
  name                     = local.slug
  friendly_name            = var.friendly_name
  configure_flow           = authentik_flow.setup.uuid
  resident_key_requirement = var.resident_key_requirement
  user_verification        = var.user_verification
  authenticator_attachment = var.authenticator_attachment
  hints                    = var.hints
  device_type_restrictions = var.device_type_restrictions
  max_attempts             = var.max_attempts
}

resource "authentik_flow_stage_binding" "setup" {
  target = authentik_flow.setup.uuid
  stage  = authentik_stage_authenticator_webauthn.setup.id
  order  = 0
}
