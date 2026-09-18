output "cert_generator_job_name" {
  description = "cert-generator Job name, `<fullname>-cert-generator`. The chart's pod template sets no labels, so that pod is only selectable by `job-name`."
  value       = "${local.ngf_fullname}-cert-generator"
}
