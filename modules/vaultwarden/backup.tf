module "backup" {
  source    = "../storage/backup/schedule"
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  tiers = ["daily", "weekly", "monthly"]
}
