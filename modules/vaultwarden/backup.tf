module "backup" {
  source    = "../storage/backup/schedule"
  target    = "vaultwarden-data"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  selector  = local.labels
}
