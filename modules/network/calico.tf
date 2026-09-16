
# v3.32 moved the CRDs out of the tigera-operator chart into `crd.projectcalico.org.v1`, and helm
# never upgrades or deletes `crds/` -- hence the bootstrap apply, triggered by the version alone.
# --force-conflicts takes over CRDs the helm provider itself server-side-applied; verified safe:
# v3.32.2 drops no served version (0 dropped, 0 added) and the chart now ships no `crds/` to re-conflict.
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
    # The Installation/APIServer/Goldmane/Whisker CRs this chart renders need their CRDs first.
    terraform_data.calico_crds,
  ]
}

