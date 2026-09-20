module "backup" {
  source    = "../../../storage/backup/schedule"
  target    = "authentik-postgres-data"
  namespace = var.namespace
  selector = {
    "app.kubernetes.io/name"     = "postgresql"
    "app.kubernetes.io/instance" = "authentik"
  }

  tiers = ["daily"]
}
