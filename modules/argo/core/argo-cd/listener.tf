# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute is
# rendered by the argo-cd chart itself (server.httproute), so this module declares
# only the ListenerSet; the submodule creates the cross-namespace ReferenceGrants
# for both ListenerSet and HTTPRoute attachment.
module "expose" {
  source            = "../../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

# The bare host intentionally serves the chart's own login page. Do not hijack
# `Exact /` into /auth/login: argocd-server's OIDC callback falls back to the base
# href (`/`) when no return_url is supplied, so the browser loops until
# ERR_TOO_MANY_REDIRECTS. Argo CD ships no setting to skip its login page -- the SSO
# button is the entrypoint.
