# Exposure via the shared private gateway: HTTPS listener + HTTPRoute to the ClusterIP
# service (plain HTTP backend on 2746).
module "expose" {
  source            = "../../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = local.server_service
  backend_port      = 2746
}

# The bare host intentionally serves the UI's own login page -- same call as Argo CD
# (see ../core/argo-cd/listener.tf): hijacking `/` into the IdP login loops the
# browser on the OIDC callback. The Login button is the SSO entrypoint.
