# Exposure via the shared public gateway (kube-network): HTTPS listener
# (ntfy.<domain>, letsencrypt cert) + HTTPRoute to the ntfy ClusterIP service.
#
# The hostname is a *public* name -- *.linuxguru.net is a wildcard alias to the
# router, so no record has to be created. external-dns only publishes the
# internal vn.linuxguru.net zone and will simply ignore this host (harmless).
#
# Deliberately NOT behind the authentik proxy outpost. The web UI, the mobile
# app and Alertmanager share these same paths (the UI is a SPA at /app that then
# calls /<topic>/json, /<topic>/ws and /v1/*), so there is no way to gate "just
# the UI" without also catching the API -- and any 302 to the authentik login
# page breaks both the phone and Alertmanager. ntfy's own auth is the data
# layer here; SSO would only have protected an inert shell.
module "expose" {
  source            = "../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.name
  backend_port      = 80

  # The route references the Service by name only (no implicit edge). NGF would
  # recover once the Service appears, but ordering it means a clean first apply.
  depends_on = [helm_release.ntfy]
}
