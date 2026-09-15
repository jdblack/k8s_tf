# The NGF chart does not ship the Gateway API CRDs, so install them here: cluster-scoped,
# installed exactly once, re-run only when triggers_replace changes. NGF's own CRDs
# (gateway.nginx.org/*) come from the chart's crds/.
#
# Fresh cluster: apply core BEFORE any stack creating Gateway API resources.
resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway-api standard CRDs @ NGF v2.6.7"]
}
