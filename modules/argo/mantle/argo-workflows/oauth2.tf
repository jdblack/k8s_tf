# Authentik OIDC client for the Workflows UI SSO, the k8s secret holding the client
# credentials the chart's server.sso config points at, and the namespace-local copy
# of the private CA ConfigMap the server mounts to trust the issuer's TLS cert.
module "auth" {
  name         = var.name
  redirect_uri = "https://${local.fqdn}/oauth2/callback"
  source       = "../../../auth/authentik/oidc_provider"

  # Tile icon + open in a new tab. No dedicated Argo Workflows icon exists in the
  # dashboard-icons/selfh.st sets, so keep the official Argo Project GitHub avatar.
  meta_icon       = "https://avatars.githubusercontent.com/u/30269780?s=60&v=4"
  open_in_new_tab = true
}

resource "kubernetes_secret_v1" "oauth_secret" {
  metadata {
    namespace = var.namespace
    name      = local.sso_secret
  }
  data = {
    client_id = module.auth.client_id,
    secret    = module.auth.client_secret
  }
}

# Private CA (linuxguru-ca) that signs the Authentik issuer's TLS cert.
# cert_manager publishes it as a ConfigMap in `default`, named after the issuer
# (var.cert_issuer). It is a data source, so its content is re-read every apply --
# a cert rotation only needs a cert_manager apply first.
data "kubernetes_config_map_v1" "local_ca" {
  metadata {
    name = var.cert_issuer
  }
}

# ConfigMap volumes can only mount from the pod's own namespace, so mirror the
# default-namespace CA ConfigMap here. The server's subPath mount in locals.tf
# reads it; note ConfigMap subPath mounts are snapshotted at pod start, so a CA
# refresh also needs a server rollout.
resource "kubernetes_config_map_v1" "local_ca_mirror" {
  metadata {
    namespace = var.namespace
    name      = local.ca_cert_cm
  }
  data = {
    "tls.crt" = data.kubernetes_config_map_v1.local_ca.data["tls.crt"]
  }
}
