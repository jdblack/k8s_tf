# Two guests, both the private gateway's data plane, and one port between them: harbor-core and
# harbor-portal both listen on the pod's :8080, which is what the chart's own HTTPRoute backendRefs
# resolve to (`harbor.<domain>`, Service :80 -> DNAT). Everything else this chart does is in-namespace
# -- core -> registry/jobservice/portal, jobservice/registry -> redis, core -> postgres -- and rides
# the self rule. Image pulls arrive through the same door: the registry hostname resolves to the
# gateway's LAN VIP, so containerd and argo's repo-server both come in via that pod.
# Measured 2026-09-17 over 7d: gateway -> harbor-core:8080, plus the in-namespace set above; nothing
# off-cluster and nothing from another namespace.
module "ingress" {
  source = "../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "harbor-ingress"

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 8080 }]
  }]
}
