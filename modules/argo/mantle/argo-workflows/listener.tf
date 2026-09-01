# Exposure via the shared private gateway (kube-network): HTTPS listener
# (argo-wf.vn.linuxguru.net, linuxguru-ca cert) + HTTPRoute to the ClusterIP
# service (plain HTTP backend on 2746).
module "listener_set" {
  source            = "../../../network/gateway/listener_set"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "http_route" {
  source       = "../../../network/gateway/http_route"
  name         = var.name
  namespace    = var.namespace
  domain       = var.domain
  backend_name = "${var.name}-argo-workflows-server"
  backend_port = 2746
}
