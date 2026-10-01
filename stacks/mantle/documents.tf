module "documents" {
  source = "../../modules/documents"

  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  auth_namespace = var.deployment.auth.namespace

  # The outpost is this stack's only consumer of the directory, so it is wired here rather
  # than in a namespace of its own.
  ldap_uri           = module.authentik_ldap.uri
  ldap_bind_dn       = module.authentik_ldap.bind_dn
  ldap_user_base_dn  = module.authentik_ldap.users_dn
  ldap_group_base_dn = module.authentik_ldap.groups_dn
  ldap_bind_password = module.authentik_ldap.bind_password

  oidc_issuer_base = var.deployment.auth.server
}

module "authentik_ldap" {
  source = "../../modules/auth/authentik/ldap_outpost"

  namespace      = var.deployment.auth.namespace
  core_namespace = var.deployment.auth.namespace
  domain         = var.deployment.cluster.domains.private

  # oCIS authenticates users over OIDC and only reads the directory for identity and
  # groups, so the outpost's own certificate stays the one it generates at boot.
  search_mode = "direct"
}
