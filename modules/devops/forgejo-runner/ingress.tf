# Nothing dials in -- the runner only makes outbound calls -- so there is no app peer to admit.
# The baseline keeps the namespace default-deny (node host floor + scraping) and nothing else.
module "ingress_baseline" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "${var.name}-baseline-ingress"
}
