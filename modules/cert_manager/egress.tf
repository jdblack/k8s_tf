# Namespace profile, and the base is the API server: every pod this chart renders is a client of it
# (watches, leader election, cainjector's writes, the webhook's subjectaccessreviews) -- including the
# `startupapicheck` hook Job, which carries only `job-name` labels, the shape a closed floor broke in
# `media`. The namespace-wide selector is what covers the pods no call names.
module "egress" {
  source = "../network/firewalls/egress"

  namespace     = kubernetes_namespace_v1.namespace.metadata[0].name
  name          = "cert-manager-egress"
  allow_k8s_api = true
}

# Only the controller leaves the cluster, and it has to: ACME registration and renewals at
# acme-v02.api.letsencrypt.org, the Route53 API for DNS-01, and the public recursors locals.tf pins.
# Invisible in Whisker (zero records for this namespace in a 30-day query) -- measured instead from
# the RBAC bindings and the log's own reflectors, with every ACME order reading `valid`.
module "egress_controller" {
  source = "../network/firewalls/egress"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "cert-manager-controller-egress"
  pod_selector = { "app.kubernetes.io/name" = "cert-manager", "app.kubernetes.io/component" = "controller" }

  allow_internet = true
}
