output "stage_id" {
  value = authentik_stage_authenticator_webauthn.setup.id
}

output "flow_id" {
  value = authentik_flow.setup.uuid
}

output "flow_slug" {
  value = authentik_flow.setup.slug
}
