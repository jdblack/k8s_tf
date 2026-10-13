# Its own namespace on purpose: the runner executes arbitrary repo code, so it gets a blast
# radius separate from the Forgejo instance it serves.
variable "namespace" { default = "devops-forgejo-runner" }
variable "name" { default = "forgejo-runner" }

# The instance URL the runner registers and polls, e.g. https://git.example.net. It is the
# public name, so the traffic rides the private gateway rather than the Forgejo pod directly.
variable "instance_url" { type = string }

# Registration name shown in Forgejo's runner list; pairs with the token.
variable "registration_name" { default = "forgejo-runner" }

# The registration token from Forgejo (Admin -> Actions -> Runners -> Create new runner). It is
# bootstrap-only: the chart's pre-install Job exchanges it once for the runner's own uuid+token,
# which land in a chart-owned Secret that survives upgrades.
variable "registration_token" {
  type      = string
  sensitive = true
}

# Labels decide which jobs this runner picks up, and how they run. `docker://` = the container
# executor (which needs the DinD sidecar below); a bare `host` label would run with no isolation.
variable "labels" {
  type = list(string)
  default = [
    "ubuntu-latest:docker://node:20-bookworm",
    "docker:docker://data.forgejo.org/oci/alpine:3.20",
  ]
}

# Jobs to run at once. Keep at 1: the shared DinD daemon lets concurrent jobs see each other.
variable "capacity" { default = 1 }
variable "job_timeout" { default = "3h" }

# We build our own copy of this chart. `support/forgejo-chart-vendor` chains:
#   upstream code.forgejo.org/forgejo-helm/forgejo-runner (publishes NO OCI artifact)
#     -> pull-mirror git.vn.linuxguru.net/forgejo/forgejo-runner   (native, refreshed every 72h)
#     -> clone + `helm package` + `helm push` to this Harbor path  (public project, anonymous pull)
# Re-run that script to publish a newer chart, then bump chart_version to match its output.
variable "chart_repository" { default = "oci://harbor.vn.linuxguru.net/library/charts" }
variable "chart" { default = "forgejo-runner" }
variable "chart_version" { default = "0.7.5" }

variable "image_registry" { default = "code.forgejo.org" }
variable "image_repository" { default = "forgejo/runner" }
variable "image_tag" { default = "12.7.3" }

# The private gateway fronts the Forgejo instance; the runner reaches it, its git repos and the
# actions it clones through the same gateway address.
variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
