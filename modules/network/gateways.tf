module "gateway" {
  for_each = toset(["public", "private"])

  source       = "./gateway"
  namespace    = var.namespace
  name         = each.key
  release_name = "ngf-${each.key}"
  helm_version = var.helm_ngf_version

  depends_on = [kubernetes_namespace_v1.namespace]
}

moved {
  from = module.gateway_public
  to   = module.gateway["public"]
}

moved {
  from = module.gateway_private
  to   = module.gateway["private"]
}
