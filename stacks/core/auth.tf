resource "kubernetes_namespace_v1" "auth" {
  metadata {
    name = "kube-auth"
  }
}

locals {
  # The official ownCloud clients carry a compiled-in client id, but oCIS verifies every client's
  # token against a single issuer, and authentik ties one client id to each application/issuer. So
  # the mobile apps' fixed ids are aliased onto the desktop client's id -- which the oCIS provider
  # already serves -- and their tokens then come out under the issuer oCIS trusts. See the module.
  owncloud_oauth_aliases = {
    "e4rAsNUSIUs0lF4nbv9FmCeUkTlV9GdgTLDH1b5uie7syb90SzEVrbN7HIpmWJeD" = "xdXOt13JKxym1B1QcEncf2XDkLAexMBFwiT9j6EfhhHFJhs2KM9jbjTmf8JBXE69"
    "mxd5OQDk6es5LzOzRvidJNfXLUZS2oN3oUFeXPP8LpPrhx3UroJFduGEYIBOxkY1" = "xdXOt13JKxym1B1QcEncf2XDkLAexMBFwiT9j6EfhhHFJhs2KM9jbjTmf8JBXE69"
  }
}

module "authentik" {
  source      = "../../modules/auth/authentik/core"
  namespace   = "kube-auth"
  domain      = var.deployment.cluster.domains.private
  fqdn        = "auth.${var.deployment.cluster.domains.private}"
  cert_issuer = var.deployment.cert_manager.external_issuer
  pod_cidr    = var.deployment.network.pod_cidr

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  # oCIS resolves every account over LDAP, so it has to be allowed in at the outpost.
  ldap_client_namespaces = ["documents"]

  depends_on = [kubernetes_namespace_v1.auth]
}

# Fronts authentik's authorization and token endpoints so the ownCloud mobile apps' fixed client
# ids can reach the provider oCIS trusts, without relaxing oCIS's own token verification.
module "oidc_client_alias" {
  source = "../../modules/auth/authentik/oidc_client_alias"

  namespace = kubernetes_namespace_v1.auth.metadata[0].name

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  aliases = local.owncloud_oauth_aliases

  depends_on = [module.authentik]
}
