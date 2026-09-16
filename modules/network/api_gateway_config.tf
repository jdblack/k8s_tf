# The NGF chart does not ship the Gateway API CRDs, so install them here: cluster-scoped,
# installed exactly once, re-run only when triggers_replace changes.
#
# Fresh cluster: apply core BEFORE any stack creating Gateway API resources.
resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.1" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway-api standard CRDs @ NGF v2.7.1"]
}

# NGF's own CRDs (gateway.nginx.org/*) *are* vendored in the chart's crds/ -- but Helm only
# ever applies that directory on `helm install`: an upgrade does not touch it (see
# `helm upgrade --help`, --skip-crds), so without this the cluster keeps whatever schema the
# first install happened to carry and stays behind every chart bump. Same source the chart
# vendors, pinned to the same tag as the chart in gateway/variables.tf, applied server-side.
# Safe on a running controller: NGF filters its controllers by CRD existence, so the new
# kinds (ExternalLoadBalancer, PayloadProcessor) simply stay inactive until they exist.
resource "terraform_data" "ngf_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd?ref=v2.7.1" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway.nginx.org CRDs @ NGF v2.7.1"]
}
