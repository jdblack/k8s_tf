locals {
  rules = [
    {
      alert = "CertManagerCertificateExpiringCritical"
      expr  = "certmanager_certificate_expiration_timestamp_seconds - time() < 7 * 24 * 3600"
      "for" = "1h"

      labels = { severity = "critical" }

      annotations = {
        summary     = "Certificate {{ $labels.namespace }}/{{ $labels.name }} expires in under 7 days"
        description = "Issuer {{ $labels.issuer_name }} has not renewed it, and every listener using it fails once it lapses."
      }
    },
    {
      # Renewal runs 30 days out, so 21 days left means an attempt already failed.
      alert = "CertManagerCertificateExpiringSoon"
      expr  = "certmanager_certificate_expiration_timestamp_seconds - time() < 21 * 24 * 3600"
      "for" = "6h"

      labels = { severity = "warning" }

      annotations = {
        summary     = "Certificate {{ $labels.namespace }}/{{ $labels.name }} expires in under 21 days"
        description = "Check the Certificate and its Order events: renewal is retrying and failing."
      }
    },
    {
      alert = "CertManagerCertificateNotReady"
      expr  = "certmanager_certificate_ready_status{condition=\"False\"} == 1"
      "for" = "1h"

      labels = { severity = "warning" }

      annotations = {
        summary     = "Certificate {{ $labels.namespace }}/{{ $labels.name }} is not ready"
        description = "cert-manager has not issued or renewed it, so the route behind it serves an invalid or missing certificate."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "cert-manager"
      namespace = var.namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "cert-manager"
        rules = local.rules
      }]
    }
  })
}
