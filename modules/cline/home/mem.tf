# The DEDICATED ellmephant: memory for the (future) resident Cline, kept SEPARATE from the shared
# store so a resident, prompt-injectable agent cannot touch the real memories. James offered three
# choices (share / dedicate / wait for areas); this is "dedicate", chosen deliberately and
# reversibly. The destination is a scoped AREA of the shared store once namespaces ship.
#
# Pet-named `mempal` so "which ellmephant?" is never ambiguous; reaches it at mempal.cline-home:8888.
# Reuses the same house chart pin the shared instance runs.
resource "helm_release" "mempal" {
  name       = "mempal"
  namespace  = kubernetes_namespace_v1.home.metadata[0].name
  repository = "oci://harbor.vn.linuxguru.net/library/charts"
  chart      = "ellmephant"
  version    = "0.2.0"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    fullnameOverride = "mempal"

    image = {
      repository = "harbor.vn.linuxguru.net/library/ellmephant"
      tag        = "sha-27a4266"
    }

    # cpu limit is explicit ON PURPOSE: leave it unset and the namespace LimitRange caps it at
    # 250m, at which point embedding crawls.
    resources = {
      requests = { cpu = "100m", memory = "1Gi" }
      limits   = { cpu = "2", memory = "4Gi" }
    }

    persistence = {
      enabled      = true
      storageClass = "longhorn"
      size         = "2Gi"
    }
  })]
}
