# The web UI is always fronted by the authentik outpost
# (modules/auth/authentik/outpost, same namespace): this route points the public
# hostname at the outpost Service, which authenticates then proxies to the
# qbittorrent Service. Same shape as the *arr apps -- name "<app>-auth",
# parentRef the "<app>" ListenerSet (listener.tf), backend_port 9000.
#
# Torrent traffic (21010) does NOT go through here -- it is served by the
# separate LoadBalancer Service in service.tf.
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


