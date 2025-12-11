
module odoo {
  count = 0
  source = "../modules/odoo"
  namespace = "odoo"
  cert_authority = var.deployment.cert_authorities["private"]
  domain = var.deployment.domains["private"]
}
