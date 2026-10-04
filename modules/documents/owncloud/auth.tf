# Client id and secret both come back out of here, so the web UI is configured from the
# provider that was actually created rather than from a name kept in two places.
module "oidc" {
  source = "../../auth/authentik/oidc_provider"

  name = var.name

  # Compiled into the desktop client; web reads its id back out of this module.
  client_id = var.desktop_client_id

  redirect_uri = "https://${local.fqdn}/"

  extra_redirect_uris = [
    "https://${local.fqdn}/oidc-callback.html",
    "https://${local.fqdn}/oidc-silent-redirect.html",

    # The mobile apps' custom-scheme callbacks. Their client ids are aliased onto this provider
    # by the auth-layer proxy, so the redirects have to be allowed here too.
    "oc://android.owncloud.com",
    "oc://ios.owncloud.com",
    "oc.ios://ios.owncloud.com",
  ]

  # Desktop login listens on a fresh loopback port, so only a pattern can name it.
  regex_redirect_uris = ["http://127\\.0\\.0\\.1:\\d+"]

  # ownCloud Web does the code exchange in the browser, so there is nowhere to keep a
  # client secret; as a confidential client every login fails with invalid_client.
  client_type = "public"

  bind_app = true

  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/owncloud.svg"
  meta_launch_url = "https://${local.fqdn}"
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
