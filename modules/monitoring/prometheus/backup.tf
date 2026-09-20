module "backup" {
  source    = "../../storage/backup/schedule"
  target    = "grafana-storage"
  namespace = var.namespace
  selector  = { "app.kubernetes.io/name" = "grafana" }

  tiers = ["weekly"]
}
