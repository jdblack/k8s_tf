module "backup" {
  source    = "../../storage/backup/schedule"
  namespace = var.namespace

  tiers = ["weekly"]
}
