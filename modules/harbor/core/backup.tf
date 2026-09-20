module "backup" {
  source    = "../../storage/backup/schedule"
  target    = "harbor-database-data"
  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  selector = {
    "app.kubernetes.io/name"      = "harbor"
    "app.kubernetes.io/component" = "database"
  }

  tiers = ["weekly", "monthly"]
}
