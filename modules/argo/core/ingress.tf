# Two guests, one of them a port list: the private gateway's data plane on argocd-server's :8080 and
# on argo-workflows-server's :2746 (the two HTTPRoutes' backend ports, Service :80 -> DNAT again).
# Namespace-wide, because argo-wf runs arbitrary container images as workflow pods and a namespace that
# curates only the two pods it can name leaves the rest an ingress hole nobody wrote; the self rule
# carries the chart's own chatter (server -> redis, application-controller -> repo-server).
# Measured 2026-09-17 over 7d: gateway -> argocd-server:8080, the in-namespace set above, nothing else.
module "ingress" {
  source = "../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "argo-ingress"

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 8080 }, { port = 2746 }]
  }]
}
