module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace      = var.namespace
  name           = "media-baseline-egress"
  allow_internet = true
}

module "egress_ngf" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

module "egress_ngf_cert_generator" {
  source = "../network/firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-cert-generator-egress"
  pod_selector  = { "job-name" = module.gateway.cert_generator_job_name }
  allow_k8s_api = true
}

module "egress_outpost" {
  source = "../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "authentik-outpost-egress"
  pod_selector = { "app.kubernetes.io/name" = "authentik-outpost" }

  to_peers = [{
    namespace    = var.auth_namespace
    pod_selector = { "app.kubernetes.io/name" = "authentik", "app.kubernetes.io/component" = "server" }
    ports        = [{ port = 9000 }]
  }]
}
