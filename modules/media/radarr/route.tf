# The app is always fronted by the authentik outpost (modules/auth/authentik/
# outpost, same namespace). The chart's HTTPRoute is disabled in locals.tf and
# this manifest points the public hostname at the outpost service. Named
# "<app>-auth" so it can never collide with the chart-generated "<app>" route
# during the disable/apply transition.
module "http_route" {
  source       = "../../network/gateway/http_route"
  name         = "${var.name}-auth"
  namespace    = var.namespace
  domain       = var.domain
  hostname     = local.fqdn
  parent_name  = var.name
  backend_name = var.auth_backend
  backend_port = 9000
}
