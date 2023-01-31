resource "random_password" "db_pass" {
  length = 15
  special = false
}

resource "kubernetes_secret" "cinc"  {
  metadata {
    name = "cinc"
    namespace = var.namespace
  }
  data = {
    POSTGRES_USER = "cinc"
    POSTGRES_PASSWORD = random_password.db_pass.result
    CINC_FQDN = local.cinc_name
    POSTGRES_FQDN = local.db_name
    SEARCH_FQDN = module.search.host
    SEARCH_USER = module.search.user
    SEARCH_PASS = module.search.password
  }
}

