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

    # The pod executes arbitrary repo code and has no business holding an API token. The chart's
    # register hook carries its own ServiceAccount, so this only strips the runtime pod.
    serviceAccount = { automount = false }

    # Bound the pod so a runaway job cannot starve its node. The runner just polls and drives the
    # daemon; the daemon runs the actual job containers, so it carries the weight.
    resources = var.resources
    dind      = { resources = var.dind_resources }

    # k8smaster carries no control-plane label or taint, so the controller node is excluded by
    # hostname -- same device as modules/media/plex.tf. Untrusted code stays off the node that
    # hosts the API server, etcd and most of the cluster.
    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [{
              key      = "kubernetes.io/hostname"
              operator = "NotIn"
              values   = var.excluded_nodes
            }]
          }]
        }
      }
    }

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

            # Handed to every job container so `docker` inside a job reaches the sidecar. ALL THREE
            # ARE REQUIRED: DOCKER_HOST alone fails with "Client sent an HTTP request to an HTTPS
            # server" -- the daemon listens with TLS on 2376 (verified live in the smoke run). The
            # certs are already mounted at /certs/client by `container.options` below; these two
            # vars are what point the CLI at them.
            envs = {
              DOCKER_HOST       = "tcp://127.0.0.1:2376"
              DOCKER_TLS_VERIFY = "1"
              DOCKER_CERT_PATH  = "/certs/client"
            }
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
