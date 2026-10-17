# THE BRAIN. The software is the genus (`ellmephant`); the instance that IS someone takes that
# someone's name. ★ But an OBJECT NAME ANSWERS A DIFFERENT QUESTION: a pod called `stet-5468b79c44-…`
# says nothing about what it is, so the workload is `stet-brain` — the anatomy, the same way the hand
# is `stet-hand`. The ADDRESS stays the self's name (`stet.<domain>`), because that is what a client
# types and what a person says.
#
# ★ REUSED, NOT REBUILT: this is the same submodule the shared `mcp` store uses — same chart, same
# encoder sizing, same exposure trio. A second brand of brain would be a second set of traps.
module "brain" {
  source = "../../mcp/ellmephant"

  name      = "${var.name}-brain"
  namespace = kubernetes_namespace_v1.room.metadata[0].name

  domain      = var.domain
  cert_issuer = var.cert_issuer
  hostname    = "${var.name}.${var.domain}"

  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  storage_class = var.storage_class
  storage_size  = var.storage_size
  chart_version = var.chart_version
  image_tag     = var.image_tag

  # The room has to exist before the release's Service, PVC and policies land in it.
  depends_on = [kubernetes_namespace_v1.room]
}
