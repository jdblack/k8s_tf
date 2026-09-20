locals {
  # Targets stay queryable on the Schedule; Backups carry velero.io/schedule-name instead.
  target_label = { "backup.linuxguru.net/target" = var.target }
}
