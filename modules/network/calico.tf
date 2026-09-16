
# Calico's CRDs are no longer part of the tigera-operator chart. v3.32 dropped the chart's
# whole `crds/` directory -- helm never upgrades or deletes crds/ resources, so upstream
# moved them to a separate `crd.projectcalico.org.v1` chart and its README now says to
# apply/upgrade the CRDs *before* upgrading the operator chart. Same bootstrap shape as
# api_gateway_config.tf; the version in `triggers_replace` is the whole coupling, so the
# URL and the trigger cannot drift apart.
#
# The 32 CRDs carry no helm ownership metadata, but the helm provider server-side-applied
# them (they are owned by field manager `terraform-provider-helm`), so the apply needs
# --force-conflicts to take over `.spec.versions` and one kubebuilder annotation. That is
# safe here because v3.32.2 drops NO served version -- verified by diffing
# `spec.versions[*].name` per CRD against the live cluster: 0 dropped, 0 added, 0 CRDs
# removed from the set (the only set changes are two new CRDs). The chart has no crds/ any
# more, so this cannot re-conflict on a later upgrade.
resource "terraform_data" "calico_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/projectcalico/calico/${var.helm_calico_version}/manifests/operator-crds.yaml
    EOT
  }

  triggers_replace = ["calico CRDs @ ${var.helm_calico_version}"]
}

resource "helm_release" "calico" {
  namespace  = var.namespace
  name       = "calico"
  repository = "https://docs.tigera.io/calico/charts"
  chart      = "tigera-operator"
  version    = var.helm_calico_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values.calico)]
  depends_on = [
    kubernetes_namespace_v1.namespace,
    # The Installation/APIServer/Goldmane/Whisker CRs this chart renders need their CRDs to
    # exist first.
    terraform_data.calico_crds,
  ]
}

