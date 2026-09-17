# THIS NAMESPACE IS NOT CURATED AS A WHOLE, on purpose. The two NGF data planes have to dial backends
# in every namespace in the cluster, which no peer list can state -- it is the standing decline in
# `modules/network/firewalls/README.md`, and the same decline `media` and `blender` carry. What is
# closed here is the two chart Deployments (both releases share these labels, so one call covers the
# pair) and the cert-generator hook pods they render on every helm run.

# API + DNS, the same construction `media` uses for its own gateway: wholesale watches on connections
# that never end are never emitted into the flow log, so this is argued from the RBAC bindings (the
# controller watches Gateway API resources cluster-wide) rather than measured -- a query for
# `source_namespace=kube-network, dest_port=6443` returns zero items, and always will.
module "egress_ngf" {
  source = "./firewalls/egress"

  namespace     = var.namespace
  name          = "ngf-control-plane-egress"
  pod_selector  = { "app.kubernetes.io/name" = "nginx-gateway-fabric" }
  allow_k8s_api = true
}

# The hook pod carries no chart labels -- only `job-name` -- and each release has its own, hence two
# calls. Both names come from their gateway module so a renamed release follows; each exists for a few
# seconds per helm run, so a selector that currently matches nothing is the normal state.
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
