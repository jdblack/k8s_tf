output "cert_generator_job_name" {
  description = "cert-generator Job name, `<fullname>-cert-generator`. The chart's pod template sets no labels, so that pod is only selectable by `job-name`."
  value       = "${local.ngf_fullname}-cert-generator"
}

# Read back from the object: a value from a resource, unlike the variable that named it, carries the
# ordering edge that puts whoever spends it after the Gateway and the CRDs it needed.
output "name" {
  value = kubectl_manifest.gateway.name
}

output "namespace" {
  value = kubectl_manifest.gateway.namespace
}
