# Gateway API CRDs (gateway.networking.k8s.io/*) are NOT shipped by the NGF
# chart, so install them here. They are CLUSTER-SCOPED API definitions shared by
# every Gateway / GatewayClass / HTTPRoute / ListenerSet in the cluster, so they
# are installed exactly once by this module (run from the core stack) -- never
# per-gateway. Idempotent (`kubectl apply`), and only re-runs if
# triggers_replace changes. The NGF chart installs its OWN CRDs
# (gateway.nginx.org/*) automatically from its crds/ directory, so this only
# covers the standard Gateway API resources (Gateway, HTTPRoute, ReferenceGrant,
# etc.).
#
# Bootstrap note: on a brand-new cluster, apply this module (i.e. the core
# stack) BEFORE any stack that creates Gateway API resources -- `tofu plan` /
# `apply` requires these CRDs to exist (the Gateway manifest needs their
# schema). `tofu apply -target=module.network.terraform_data.gateway_api_crds`
# also works.
resource "terraform_data" "gateway_api_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.6.7" | kubectl apply --server-side -f -
    EOT
  }

  triggers_replace = ["gateway-api standard CRDs @ NGF v2.6.7"]
}
