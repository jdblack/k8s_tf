# DNS + own namespace only: the pod originates nothing else (no push relay, no SMTP, no API
# watches), and the self rule is kept for a second pod that may arrive later.
module "egress" {
  source = "../network/firewalls/egress"

  namespace    = kubernetes_namespace_v1.this.metadata[0].name
  name         = "vaultwarden-egress"
  pod_selector = local.labels
}
