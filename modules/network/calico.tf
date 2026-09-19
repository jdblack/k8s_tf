locals {
  calico_crds_url = "https://raw.githubusercontent.com/projectcalico/calico/${var.helm_calico_version}/manifests/operator-crds.yaml"
}

# The chart ships no CRDs since v3.32; the operator owns them once present, so only fill gaps.
data "external" "calico_crds_missing" {
  program = ["bash", "-c", <<-EOT
    set -eu
    names=$(kubectl create --dry-run=client -o name -f ${local.calico_crds_url})
    live=$(kubectl get crd -o name)
    missing=""
    for crd in $names; do
      case "$live" in *"$crd"*) continue ;; esac
      if [ -z "$missing" ]; then missing="$crd"; else missing="$missing,$crd"; fi
    done
    printf '{"missing":"%s"}\n' "$missing"
  EOT
  ]
}

resource "terraform_data" "calico_crds" {
  count = data.external.calico_crds_missing.result.missing == "" ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl apply --server-side --force-conflicts --field-manager=tofu-calico-crds -f ${local.calico_crds_url}
    EOT
  }
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
    terraform_data.calico_crds,
  ]
}
