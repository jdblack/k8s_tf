module "gateway" {
  for_each = toset(["public", "private"])

  source       = "./gateway"
  namespace    = var.namespace
  name         = each.key
  release_name = "ngf-${each.key}"
  helm_version = var.helm_ngf_version

  # nginx's 60s read default severs idle websockets (UI "connection lost" after a tab switch).
  proxy_timeout = { read = "1h" }

  # The Gateway is itself a Gateway API object: it cannot land before the CRDs do.
  depends_on = [kubernetes_namespace_v1.namespace, terraform_data.gateway_api_crds]
}
