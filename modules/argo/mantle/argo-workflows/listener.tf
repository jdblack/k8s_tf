# Exposure via the shared private gateway (kube-network): HTTPS listener
# (argo-wf.vn.linuxguru.net) + HTTPRoute to the ClusterIP
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

moved {
  from = module.listener_set
  to   = module.expose.module.listener_set
}

moved {
  from = module.http_route
  to   = module.expose.module.http_route[0]
}

# The bare host intentionally serves the UI's own login page -- same call as
# Argo CD (see ../core/argo-cd/listener.tf): the IdP-first redirect was a
# `redirect_route` facade rather than a feature of either app, and it isn't
# worth the failure mode (an OIDC callback that lands back on the hijacked path
# loops forever). The UI's Login button is the SSO entrypoint. Rationale:
# memory-bank/progress.md.
