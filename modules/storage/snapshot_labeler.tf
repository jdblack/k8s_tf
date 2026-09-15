# The one writer of recurring-job labels -- see longhorn_jobs.tf for why they
# must live on the Volume CR and nowhere else.
#
# kubectl in a local-exec, same as modules/network/api_gateway_config.tf: the
# target is a CR created by the CSI provisioner, which this repo otherwise does
# not manage, and owning the Volume CR via kubernetes_manifest would fight
# Longhorn's own controllers.
#
# A missing PVC is a warning, not a failure: this runs from stacks/core, BEFORE
# the stacks that create the PVCs. Re-run core (or the one-liner in README.md)
# once those are up; until then the coverage audit fails loudly, which is the
# point.
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
      # Add the wanted groups FIRST, then strip the known leftovers: doing it the
      # other way round leaves the volume briefly group-less, which is exactly
      # when Longhorn re-adds its built-in `default` group.
      kubectl -n ${var.longhorn_namespace} label "volumes.longhorn.io/$pv" \
        ${join(" ", [for g in each.value : "recurring-job-group.longhorn.io/${g}=enabled"])} --overwrite
      kubectl -n ${var.longhorn_namespace} label "volumes.longhorn.io/$pv" \
        ${join(" ", [for g in local.snapshot_known_groups : "recurring-job-group.longhorn.io/${g}-" if !contains(each.value, g)])} --overwrite
    EOT
  }

  # Only re-runs when the desired groups change; re-running core after a volume
  # moves tier is enough to converge it.
  triggers_replace = [join(",", sort(each.value))]

  depends_on = [helm_release.longhorn]
}
