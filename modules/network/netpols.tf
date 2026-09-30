module "egress_ngf" {
  source    = "./firewalls/policy"
  direction = "egress"

  namespace     = var.namespace
  name          = "ngf-control-plane-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

module "egress_ngf_cert_generator" {
  for_each = module.gateway

  source    = "./firewalls/policy"
  direction = "egress"

  namespace     = var.namespace
  name          = "ngf-${each.key}-cert-generator-egress"
  pod_selector  = { "job-name" = each.value.cert_generator_job_name }
  allow_k8s_api = true
}
