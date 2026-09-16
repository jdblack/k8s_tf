# DNS plus this namespace, and that is the whole measured list. Over a 30-day Whisker window
# the only flows this pod *originates* are UDP/53 to coredns; everything else is inbound (the
# private gateway's data plane dials it on 80), which an egress policy never sees and never
# grants. No push relay (no PUSH_ENABLED), no SMTP (mail is off), no API watches -- so no
# allow_internet, no allow_k8s_api, and no to_cidrs for the LAN.
#
# The self rule is kept even though replicas = 1 and nothing else lives in the namespace: it
# costs one rule, and a second pod here (or a future one) failing to reach this one would read
# as a broken app rather than as policy.
#
# Selected by the Deployment's own labels rather than the namespace, so this covers exactly the
# pods `deployment.tf` owns and follows them if that label ever changes.
module "egress" {
  source = "../network/firewalls/egress"

  namespace    = kubernetes_namespace_v1.this.metadata[0].name
  name         = "vaultwarden-egress"
  pod_selector = local.labels
}
