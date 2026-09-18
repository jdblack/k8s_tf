output "cert_generator_job_name" {
  description = "Name of the chart's cert-generator Job, and therefore of the pod it creates -- the only handle on it, since the pod template sets no labels. `<fullname>-cert-generator`, matching the chart's own naming."
  value       = "${local.ngf_fullname}-cert-generator"
}
