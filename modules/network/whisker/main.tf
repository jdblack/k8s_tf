# authentik proxy provider + application for whisker, bound to var.group_name, plus
# the outpost + its service-account token (see proxy_app/README.md).
module "auth" {
  source = "../../auth/authentik/proxy_app"

  apps = {
    whisker = {
      external_host = "https://whisker.${var.domain}"
      internal_host = "http://${var.whisker_service}.${var.namespace}.svc.cluster.local:${var.whisker_port}"
      icon          = var.icon
    }
  }

  outpost_name = var.outpost_name
  group_name   = var.group_name
}

# The outpost lives in this namespace (calico-system), so the outpost -> whisker hop
# needs no cross-namespace policy.
module "outpost" {
  source = "../../auth/authentik/outpost"

  namespace    = var.namespace
  outpost_name = var.outpost_name
  service_name = var.outpost_service
  core_url     = "http://authentik-server.${var.auth_namespace}.svc.cluster.local:80"
  browser_url  = "https://auth.${var.domain}"
  token        = module.auth.outpost_token
}

# Backend is the OUTPOST, not whisker itself: the route is authenticated.
module "expose" {
  source = "../gateway/expose"

  name              = "whisker"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.outpost_service
  backend_port      = 9000
}

# NOTE the tigera-operator ALREADY ships pod-scoped netpols for these pods:
#   - `whisker` : deny-all POD ingress (port-forward still works -- host traffic)
#   - `goldmane`: one ingress rule on 7443 with NO `from` -> any source, and
#                 NetworkPolicies only UNION, so it cannot be tightened from here.
# The only thing added here is the outpost's allowance.
module "firewall_whisker" {
  source = "../firewalls/limited_ingress"

  namespace    = var.namespace
  policy_name  = "whisker-ingress"
  pod_selector = { "app.kubernetes.io/name" = "whisker" }

  # The outpost, which lives in this namespace. Every other namespace stays denied
  # by the operator's own `whisker` netpol.
  allowed_ingress_namespaces = [var.namespace]
}

# Unrelated to the module above: the outpost module ships an Egress-only,
# default-deny policy, and calico-system deliberately has no namespace-wide
# basic_internet posture (a namespace-wide egress default-deny there would break
# Calico's control plane). So open exactly what the outpost needs: DNS and whisker.
module "outpost_egress" {
  source = "../firewalls/policy"

  name      = "whisker-outpost-egress"
  namespace = var.namespace
  pod_selector = {
    "app.kubernetes.io/name"     = "authentik-outpost"
    "app.kubernetes.io/instance" = var.outpost_name
  }
  policy_types = ["Egress"]

  egress_rules = [
    {
      peers = [{
        namespace_selector = { "kubernetes.io/metadata.name" = var.system_namespace }
        pod_selector       = { "k8s-app" = "kube-dns" }
      }]
      ports = [{ protocol = "UDP", port = 53 }, { protocol = "TCP", port = 53 }]
    },
    {
      peers = [{
        namespace_selector = { "kubernetes.io/metadata.name" = var.namespace }
        pod_selector       = { "app.kubernetes.io/name" = var.whisker_service }
      }]
      ports = [{ protocol = "TCP", port = var.whisker_port }]
    },
  ]
}
