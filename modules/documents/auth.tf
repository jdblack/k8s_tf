module "auth" {
  source = "../auth/authentik/oidc_provider"

  name = var.name

  # The path is allauth's openid_connect callback for the provider_id set in the app config.
  redirect_uri = "https://${local.fqdn}/accounts/oidc/authentik/login/callback/"

  group_id = var.oidc_group_id

  meta_icon = local.icon
}
