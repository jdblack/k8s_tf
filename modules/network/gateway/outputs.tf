# Names of the chart's objects that a caller cannot re-derive safely. Egress policies are the
# consumer: the cert-generator is a helm hook whose pod carries no chart labels (only `job-name`),
# so a namespace that closes itself from the inside has to name it or break the next upgrade.
output "cert_generator_job_name" {
  description = "Name of the chart's cert-generator Job, and therefore of the pod it creates -- the only handle on it, since the pod template sets no labels. `<fullname>-cert-generator`, matching the chart's own naming."
  value       = "${local.ngf_fullname}-cert-generator"
}
