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
    terraform_data.calico_crds,
  ]
}
