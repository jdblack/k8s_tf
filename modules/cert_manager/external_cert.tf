
resource "kubectl_manifest" "external_issuer" {
  yaml_body  = yamlencode(local.external_issuer)
  depends_on = [helm_release.release, kubernetes_secret_v1.certman_route53_secret]
}

locals {
  external_issuer = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name      = var.external_issuer_name
      namespace = var.namespace
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        solvers = [
          {
            dns01 = {
              route53 = {
                accessKeyID = var.data["AWS_ACCESS_KEY_ID"]
                # `hostedZoneID` is the real API field (`zoneid` never existed:
                # the server pruned it, which left the solver to derive the zone
                # from SOA lookups against the pod's resolver). For a .vn host
                # that derivation answers `vn.linuxguru.net` -- the LAN bind9
                # zone, which has no Route53 counterpart -- and the challenge
                # died with "zone vn.linuxguru.net not found in Route 53".
                # Pinning the zone skips discovery entirely: the TXT goes into
                # the linuxguru.net zone, which is what the public resolvers
                # Let's Encrypt uses actually serve for *.vn.linuxguru.net
                # (there is no NS delegation -- see
                # ../network/dns/route53_record/README.md).
                hostedZoneID = var.data["R53_ZONEID"]
                region       = var.data["AWS_REGION"]
                secretAccessKeySecretRef = {
                  name = "certman-route53-${var.external_issuer_name}"
                  key  = "AWS_SECRET_ACCESS_KEY"
                }
              }
            }
          }
        ]
        privateKeySecretRef = {
          name = "certman-${var.external_issuer_name}"
        }
      }
    }
  }
}

resource "kubernetes_secret_v1" "certman_route53_secret" {
  metadata {
    name      = "certman-route53-${var.external_issuer_name}"
    namespace = var.namespace
  }
  data = {
    AWS_ACCESS_KEY_ID     = var.data["AWS_ACCESS_KEY_ID"]
    AWS_SECRET_ACCESS_KEY = var.data["AWS_SECRET_ACCESS_KEY"]
    AWS_REGION            = var.data["AWS_REGION"]
  }
  depends_on = [kubernetes_namespace_v1.namespace]
}

