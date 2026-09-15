# authentik proxy app for whisker, plus the outpost and its service-account token.
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

# The outpost lives in calico-system too, so the outpost -> whisker hop is same-namespace
# and needs no policy.
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

# The tigera-operator already ships pod-scoped netpols for these pods: whisker = deny-all
# pod ingress (port-forward still works) and goldmane = one `from`-less rule on 7443, which
# policies can only union -- untightenable from here. This adds only the outpost's
# allowance.
module "firewall_whisker" {
  source = "../firewalls/limited_ingress"

  namespace    = var.namespace
  policy_name  = "whisker-ingress"
  pod_selector = { "app.kubernetes.io/name" = "whisker" }

  # The outpost, in this namespace; the operator's own whisker netpol denies everything else.
  allowed_ingress_namespaces = [var.namespace]
}

# The outpost module's policy is egress default-deny, and calico-system deliberately has
# no namespace-wide posture (one would break Calico's control plane), so open exactly what
# the outpost needs: DNS and whisker.
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
