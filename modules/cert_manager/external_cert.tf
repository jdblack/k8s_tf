
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
                # `hostedZoneID` is the real API field; `zoneid` is silently pruned, leaving the solver
                # to derive the zone from SOA lookups against the pod's resolver -- which answers the LAN
                # bind9 zone vn.linuxguru.net, so the challenge died with "zone vn.linuxguru.net not found
                # in Route 53". Pinning it puts the TXT in linuxguru.net, the zone public resolvers serve.
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

