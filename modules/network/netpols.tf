module "egress_ngf" {
  source = "./firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-control-plane-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

module "egress_ngf_cert_generator_public" {
  source = "./firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-public-cert-generator-egress"
  pod_selector  = { "job-name" = module.gateway_public.cert_generator_job_name }
  allow_k8s_api = true
}

module "egress_ngf_cert_generator_private" {
  source = "./firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-private-cert-generator-egress"
  pod_selector  = { "job-name" = module.gateway_private.cert_generator_job_name }
  allow_k8s_api = true
}
