# NGF's chart does not ship the Gateway API CRDs: cluster-scoped, installed once, re-run only when
# `triggers_replace` changes. Fresh cluster: apply core BEFORE any stack that creates Gateway API CRs.
resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.1" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway-api standard CRDs @ NGF v2.7.1"]
}

# NGF's own CRDs *are* vendored in the chart's `crds/`, but Helm only ever applies that directory on
# `helm install` -- an upgrade never touches it, so without this the cluster keeps the schema of the
# first install. Safe on a running controller: NGF filters its controllers by CRD existence, so new
# kinds simply stay inactive until they exist. Same source the chart vendors, same tag as the chart.
resource "terraform_data" "ngf_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd?ref=v2.7.1" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway.nginx.org CRDs @ NGF v2.7.1"]
}
