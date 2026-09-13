locals {
  fqdn = "${var.name}.${var.domain}"

  labels = {
    "app.kubernetes.io/name" = var.name
  }

  data_pvc_name = "${var.name}-data"

  # Longhorn joins a volume to a RecurringJob by GROUP: the
  # recurring-job-group.longhorn.io/<group> label on the PVC is copied onto the
  # volume, and the job's spec.groups must name the same group.
  snapshot_group = var.name
}
