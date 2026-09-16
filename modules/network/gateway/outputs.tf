# The chart names its cert-generator Job `<release>-nginx-gateway-fabric-cert-generator`
# and gives the hook's *pods* only the Job controller's batch labels -- never the chart's
# `app.kubernetes.io/name`. Callers that firewall API egress by pod label (media) need that
# exact label to let the hook through, so publish the name instead of re-deriving it.
output "cert_generator_job_name" {
  value       = "${var.release_name}-nginx-gateway-fabric-cert-generator"
  description = "Name of the chart's cert-generator Job, i.e. the `job-name` label on its hook pods"
}
