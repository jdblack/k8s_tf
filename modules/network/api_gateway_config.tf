resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v${var.helm_ngf_version}" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway-api standard CRDs @ NGF v${var.helm_ngf_version}"]
}

resource "terraform_data" "ngf_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd?ref=v${var.helm_ngf_version}" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway.nginx.org CRDs @ NGF v${var.helm_ngf_version}"]
}
