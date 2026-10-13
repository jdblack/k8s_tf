locals {
  # A Forgejo convention, kept visible on purpose: the instance is git.<domain> and its OIDC source is
  # registered as "authentik" (modules/devops/forgejo: local.fqdn, local.oidc_source_name). These two URIs
  # are exactly what the live provider carries; generalising this module means parameterising the pair.
  fqdn = "git.${var.domain}"
  redirect_uris = [
    "https://${local.fqdn}/user/oauth2/authentik/callback",
    "https://${local.fqdn}",
  ]

  # What the client is configured with: issuer <issuer_base>/application/o/<name>/ plus
  # .well-known/openid-configuration, no trailing slash.
  discovery_url = "${var.issuer_base}/application/o/${var.name}/.well-known/openid-configuration"

  # Copied from modules/auth/authentik/oidc_provider: a user granted through the admin/user tier is only a
  # direct member of that group, and nesting lives in the parents, so all_groups() -- not groups -- is what
  # carries the role. The built-in profile claim uses groups and would drop it.
  scope_groups_expression = <<-EOT
    return {
        "groups": [group.name for group in request.user.all_groups()],
    }
  EOT

  scope_profile_expression = <<-EOT
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

  # The provider model carries six fields oidc_provider never set (authentik defaults, visible only in a live
  # export): sub_mode, issuer_mode, include_claims_in_id_token, logout_method, access_code_validity,
  # refresh_token_threshold. They are pinned in the template rather than left to the default.

  # Each of these lands inside a YAML scalar, so it is JSON-encoded: a JSON string is also a valid YAML
  # scalar, which keeps the PEMs and the multi-line expressions on one line apiece, with no indentation to
  # get wrong and no tag-like text for the loader to resent.
  certificate_data   = jsonencode(tls_self_signed_cert.signing.cert_pem)
  key_data           = jsonencode(tls_private_key.signing.private_key_pem)
  client_secret      = jsonencode(random_password.client_secret.result)
  expression_groups  = jsonencode(local.scope_groups_expression)
  expression_profile = jsonencode(local.scope_profile_expression)

  # The model wants redirect_uris as a list of objects, which yamlencode emits exactly; indent() skips its
  # first line, so the leading newline is what gets that first line indented with the rest.
  redirect_uris_yaml = indent(8, "\n${yamlencode([
    for uri in local.redirect_uris : {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = uri
    }
  ])}")

  blueprint = templatefile("${path.module}/blueprint.tftpl", {
    name               = var.name
    fqdn               = local.fqdn
    certificate_data   = local.certificate_data
    key_data           = local.key_data
    client_secret      = local.client_secret
    expression_groups  = local.expression_groups
    expression_profile = local.expression_profile
    redirect_uris_yaml = local.redirect_uris_yaml
  })
}
