# authentik: proxy provider + application for whisker, bound to var.group_name,
# plus the outpost + its service-account token (see proxy_app/README.md).
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

# The outpost deployment/service in calico-system (same namespace as whisker, so
# the outpost -> whisker hop needs no cross-namespace policy).
module "outpost" {
  source = "../../auth/authentik/outpost"

  namespace    = var.namespace
  outpost_name = var.outpost_name
  service_name = var.outpost_service
  core_url     = "http://authentik-server.${var.auth_namespace}.svc.cluster.local:80"
  browser_url  = "https://auth.${var.domain}"
  token        = module.auth.outpost_token
}

# HTTPS listener (whisker.<domain>, private CA) on the shared private gateway +
# HTTPRoute to the OUTPOST -- not to whisker directly. Exactly the media pattern.
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

# --- in-cluster protection -------------------------------------------------
# NOTE: the tigera-operator ALREADY ships pod-scoped netpols for these pods:
#   - `whisker` : podSelector=whisker, policyTypes [Ingress,Egress] with NO
#                 ingress rules -> deny-all POD ingress (port-forward still
#                 works because that's host traffic).
#   - `goldmane`: podSelector=goldmane, ingress = one rule with ports 7443 and
#                 NO `from` -> allows ANY source on 7443 (Felix runs on every
#                 node). Kubernetes NetworkPolicies only UNION, so that cannot
#                 be tightened from here: goldmane:7443 stays cluster-readable.
# So the only thing we add is an allowance for the outpost, plus the outpost's
# own egress (its policy is Egress-only and default-deny).
module "firewall_whisker" {
  source = "../firewalls/limited_ingress"

  namespace    = var.namespace
  policy_name  = "whisker-ingress"
  pod_selector = { "app.kubernetes.io/name" = "whisker" }

  # Unions in the outpost, which lives in this namespace. Every other namespace
  # stays denied by the operator's own `whisker` netpol.
  allowed_ingress_namespaces = [var.namespace]
}

# The outpost module ships an Egress-only, default-deny policy (kube-auth:9000).
# In media the namespace-wide basic_internet posture supplies same-ns + DNS; in
# calico-system there is (deliberately) no such policy -- a namespace-wide
# egress default-deny there would break Calico's control plane. So open exactly
# what the outpost needs: DNS, and whisker itself.
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
