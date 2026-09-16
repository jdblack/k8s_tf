# authentik proxy app for whisker, plus the outpost (Deployment/Service/Secret) that fronts
# it in this namespace.
module "auth" {
  source = "../../auth/authentik/proxy_outpost"

  apps = {
    whisker = {
      external_host = "https://whisker.${var.domain}"
      internal_host = "http://${var.whisker_service}.${var.namespace}.svc.cluster.local:${var.whisker_port}"
      icon          = var.icon
    }
  }

  outpost_name   = var.outpost_name
  group_name     = var.group_name
  namespace      = var.namespace
  service_name   = var.outpost_service
  domain         = var.domain
  core_namespace = var.auth_namespace
}

# The outpost moved into the `auth` module above; these blocks carry its state across
# (drop them once the move has been applied). A whole-module `moved` cannot do this: the
# destination module already holds resources, so OpenTofu refuses the module-level mapping
# ("could not move ... existing objects already at the intended addresses") and destroys.
moved {
  from = module.outpost.kubernetes_secret_v1.api
  to   = module.auth.kubernetes_secret_v1.api
}
moved {
  from = module.outpost.kubernetes_deployment_v1.outpost
  to   = module.auth.kubernetes_deployment_v1.outpost
}
moved {
  from = module.outpost.kubernetes_service_v1.outpost
  to   = module.auth.kubernetes_service_v1.outpost
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

# All policy for this namespace is in tier.tf: the tigera-operator owns it (tier
# `calico-system`, default deny) and only a Calico CR in that tier can allow anything.
