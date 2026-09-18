module "egress_ngf" {
  source = "./firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-control-plane-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

module "egress_ngf_cert_generator" {
  for_each = module.gateway

  source = "./firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-${each.key}-cert-generator-egress"
  pod_selector  = { "job-name" = each.value.cert_generator_job_name }
  allow_k8s_api = true
}

moved {
  from = module.egress_ngf_cert_generator_public
  to   = module.egress_ngf_cert_generator["public"]
}

moved {
  from = module.egress_ngf_cert_generator_private
  to   = module.egress_ngf_cert_generator["private"]
}
