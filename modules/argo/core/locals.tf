locals {
  # argo-workflows and argo-events share this namespace and bring their own policies.
  argocd_selector = { "app.kubernetes.io/part-of" = "argocd" }

  gateway_peer = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
