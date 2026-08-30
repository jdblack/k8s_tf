
module "dispatcharr" {
  count     = 0
  source    = "./dispatcharr"
  namespace = var.namespace
  domain    = var.domain
}
