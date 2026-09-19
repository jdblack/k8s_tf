module "backup" {
  source    = "../../storage/backup/schedule"
  namespace = kubernetes_namespace_v1.namespace.metadata[0].name

  tiers = ["weekly", "monthly"]
}
