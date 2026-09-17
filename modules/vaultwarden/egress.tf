# DNS + own namespace only: the pod originates nothing else (no push relay, no SMTP, no API
# watches). `pod_selector` omitted on purpose -- a pod-scoped selector would leave a second pod, or
# a hook Job, default-allow, which is the fall-through the curtain exists to close. The floor can
# only ever add self + DNS, so covering the whole namespace costs nothing.
module "egress" {
  source = "../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = "vaultwarden-egress"
}
