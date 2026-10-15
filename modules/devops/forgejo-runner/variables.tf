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
#
# `ubuntu-latest` is the NAME workflows put in `runs-on:` (kept GitHub-shaped so a ported workflow
# needs no edit); the image is what the job's steps actually run in.
#
# Image choice: `catthehacker/ubuntu:act-*` -- the act ecosystem's image. A job container MUST
# carry all four of these (learned the hard way; see the `forgejo-runner-job-image` memory):
#   node   -- the runner execs it INSIDE the container for every JavaScript action, so
#             `actions/checkout` dies with `exec: "node": executable file not found` without it;
#   git    -- for the checkout itself;
#   docker -- the CLI, to reach the DinD sidecar;
#   bash   -- most workflows assume it, and alpine images do not have it.
# Both earlier values failed on a live run: the docs' example label (`node:20-bookworm`) had
# node + git but NO docker, and `docker:29-cli` had git + docker but NO node.
# Its size is a one-time cost -- the DinD daemon caches the image across jobs, for the pod's life.
# TODO (see the `todos` index): replace this with a lean purpose-built `library/ci-base` image
# published to Harbor, carrying the same four, so the label stops depending on a third-party image.
variable "labels" {
  type = list(string)
  default = [
    "ubuntu-latest:docker://catthehacker/ubuntu:act-22.04",
    "docker:docker://data.forgejo.org/oci/alpine:3.20",
  ]
}

# Jobs to run at once PER RUNNER POD. Keep at 1: every job in a pod shares that pod's DinD daemon, so
# concurrent jobs can see each other's containers and images. Raise concurrency with `replica_count`
# below, not this -- separate pods get separate daemons, which is the isolation these privileged pods
# exist for in the first place.
variable "capacity" { default = 1 }

# Runner PODS. Each one is a whole runner: its own process, its own privileged DinD sidecar, its own
# docker cache. This -- not `capacity` -- is how concurrency is raised: three pods run three jobs at
# once and no job can see another's.
#
# The replicas share ONE registered identity: the chart's pre-install Job registers once, and every
# replica's init container copies the same `.runner`. That is the chart's own scaling mode (it ships
# an HPA), and it is harmless -- the forge hands out a task per claim, so the pods take *different*
# tasks rather than the same one. What it costs is a truthful runner list: Forgejo shows one entry
# with the capacity it declared, not the number of pods actually running.
#
# N runners == N privileged pods (the DinD sidecar needs it) until the rootless-builder spike
# (`todo-buildah-rootless-runner`) lands. Mind the node budget: each pod's dind may burst to
# `var.dind_resources.limits`.
variable "replica_count" { default = 3 }
variable "job_timeout" { default = "3h" }

# We build our own copy of this chart. The `forgejo-chart-vendor` script
# (repo git.vn.linuxguru.net/Linuxguru/support) chains:
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

variable "resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = { cpu = "250m", memory = "256Mi" }
    limits   = { cpu = "1", memory = "1Gi" }
  }
}

variable "dind_resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = { cpu = "500m", memory = "1Gi" }
    limits   = { cpu = "4", memory = "8Gi" }
  }
}

# Nodes the runner must never land on. k8smaster has no control-plane label or taint, so it is
# named by hostname: untrusted repo code stays off the node running the API server and etcd.
variable "excluded_nodes" { default = ["k8smaster"] }
