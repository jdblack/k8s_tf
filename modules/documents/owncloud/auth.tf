# Client id and secret both come back out of here, so the web UI is configured from the
# provider that was actually created rather than from a name kept in two places.
module "oidc" {
  source = "../../auth/authentik/oidc_provider"

  name         = var.name
  redirect_uri = "https://${local.fqdn}/"

  extra_redirect_uris = [
    "https://${local.fqdn}/oidc-callback.html",
    "https://${local.fqdn}/oidc-silent-redirect.html",
  ]

  bind_app = true
}

# The outpost's bind Secret lives in the auth namespace and a pod can only read Secrets
# from its own, so the password is published again where the chart expects to find it --
# under the same key the chart's templates read.
resource "kubernetes_secret_v1" "ldap" {
  metadata {
    name      = "${var.name}-ldap-bind"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "reva-ldap-bind-password" = var.ldap_bind_password
  }
}
