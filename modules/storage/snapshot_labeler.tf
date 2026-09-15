# The only writer of the Volume-CR recurring-job labels (see longhorn_jobs.tf).
#
# local-exec kubectl: the CR is created by the CSI provisioner, so owning it through
# kubernetes_manifest would fight Longhorn's controllers. Runs from stacks/core before
# the PVCs exist, so a missing PVC warns instead of failing -- re-run core after.
resource "terraform_data" "snapshot_group" {
  for_each = local.snapshot_groups

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ns="${split("/", each.key)[0]}"
      pvc="${split("/", each.key)[1]}"
      pv=$(kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)
      if [ -z "$pv" ]; then
        echo "WARN: $ns/$pvc has no Longhorn volume yet -- re-run after its stack is applied" >&2
        exit 0
      fi
      # Add first, then strip: a group-less moment lets Longhorn re-add `default`.
      kubectl -n ${var.longhorn_namespace} label "volumes.longhorn.io/$pv" \
        ${join(" ", [for g in each.value : "recurring-job-group.longhorn.io/${g}=enabled"])} --overwrite
      kubectl -n ${var.longhorn_namespace} label "volumes.longhorn.io/$pv" \
        ${join(" ", [for g in local.snapshot_known_groups : "recurring-job-group.longhorn.io/${g}-" if !contains(each.value, g)])} --overwrite
    EOT
  }

  triggers_replace = [join(",", sort(each.value))]

  depends_on = [helm_release.longhorn]
}
