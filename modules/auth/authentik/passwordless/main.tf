# A passkey is sufficient rather than a second factor only when the identification stage
# offers it: that path stamps the pending user's backend and the auth_method, which the
# default flow's policies read to skip both the password stage and the MFA stage.
resource "authentik_stage_authenticator_validate" "passkey" {
  name                       = var.validate_stage_name
  device_classes             = ["webauthn"]
  not_configured_action      = "skip"
  webauthn_user_verification = var.user_verification
}

# Built-in object, imported rather than created: the settings below mirror it so the only
# change is webauthn_stage. Adding a field upstream also manages would fight the default
# blueprint whenever it re-applies.
resource "authentik_stage_identification" "login" {
  name                      = var.identification_stage_name
  user_fields               = ["email", "username"]
  case_insensitive_matching = true
  show_matched_user         = true
  pretend_user_exists       = true
  enable_remember_me        = false
  show_source_labels        = false

  webauthn_stage = authentik_stage_authenticator_validate.passkey.id
}
