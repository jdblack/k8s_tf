locals {
  # Targets stay queryable on the Schedule; Backups carry velero.io/schedule-name instead.
  target_label = { "backup.linuxguru.net/target" = var.target }

  # Tier policy: cadence + retention. Velero retains by TTL, not a count, so "keep N" is
  # Nx the interval: 3 dailies, 3 weeklies, 3 monthlies. Times are UTC, monthly on the 28th.
  policy = {
    daily   = { cron = "0 3 * * *", ttl = "72h" }
    weekly  = { cron = "0 4 * * 0", ttl = "504h" }
    monthly = { cron = "0 5 28 * *", ttl = "2160h" }
  }

  # An unknown tier name fails the plan here, which is the point.
  selected = {
    for tier in var.tiers : tier => {
      cron = local.policy[tier].cron
      ttl  = try(var.ttl_overrides[tier], local.policy[tier].ttl)
    }
  }
}
