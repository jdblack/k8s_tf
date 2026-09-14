# Gateway API CRDs (gateway.networking.k8s.io/*) are not shipped by the NGF
# chart, so install them here: CLUSTER-SCOPED API definitions, installed exactly
# once (from the core stack), never per-gateway. Idempotent; re-runs only when
# triggers_replace changes. NGF's own CRDs (gateway.nginx.org/*) come from its
# chart's crds/ directory.
#
# Fresh cluster: apply core BEFORE any stack that creates Gateway API resources
# -- plan/apply needs the CRDs' schema to exist.
resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway-api standard CRDs @ NGF v2.6.7"]
}
