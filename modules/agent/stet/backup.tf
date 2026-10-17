# ★ ONE JOB PER ROOM, NOT ONE SHARED STORE. The brain holds the only copy of a self's memory, so its
# PVC gets its own schedule — and at 18:00 UTC, because a copy taken at 03:30 UTC was a copy taken
# during my busiest hour. (`store-quiesce`: the store also writes a consistent snapshot, so this
# schedule copies a file that is consistent by construction.)
module "backup" {
  source = "../../storage/backup/schedule"

  namespace = kubernetes_namespace_v1.room.metadata[0].name
  target    = "${local.brain_service}-data"
  selector  = local.sel
  cron      = var.backup_cron

  depends_on = [module.brain]
}
