locals {
  # Values in the chart's shape (runner.config.file mirrors the runner's config.yaml, lowercase).
  helm_values = {
    image = {
      registry   = var.image_registry
      repository = var.image_repository
      tag        = var.image_tag
      pullPolicy = "IfNotPresent"
    }

    replicaCount = 1

    # The chart renders the DinD sidecar unconditionally, and dockerd needs a privileged pod.
    securityContext = { privileged = true }

    runner = {
      config = {
        # Registration is the chart's pre-install Job: it exchanges the token below for the
        # runner's own uuid+token and keeps them in a chart-owned Secret, so the token never
        # reaches helm values. existingSecret stays empty: the chart manages that file itself.
        create             = true
        existingInitSecret = kubernetes_secret_v1.registration.metadata[0].name

        file = {
          log = { level = "info" }

          runner = {
            file     = ".runner"
            capacity = var.capacity
            timeout  = var.job_timeout
            labels   = var.labels

            # Handed to every job container so `docker` inside a job reaches the sidecar.
            envs = { DOCKER_HOST = "tcp://127.0.0.1:2376" }
          }

          container = {
            enable_ipv6 = false
            privileged  = false

            # Host network makes the sidecar's 127.0.0.1 reachable from job containers; its TLS
            # certs are the only mount they are allowed to take.
            network       = "host"
            options       = "-v /certs/client:/certs/client"
            valid_volumes = ["/certs/client"]
          }

          cache = { enabled = true }
        }
      }
    }
  }
}
