output "validate_stage_id" {
  value = authentik_stage_authenticator_validate.passkey.id
}

output "identification_stage_id" {
  value = authentik_stage_identification.login.id
}
