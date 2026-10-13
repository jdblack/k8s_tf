locals {
  labels = {
    "app.kubernetes.io/part-of"    = "cline-home"
    "app.kubernetes.io/managed-by" = "OpenTofu"
    "cline-home/owner"             = "cline"
  }

  # The hello deployment's own selector: distinct from the namespace-wide labels so the Service
  # and Deployment agree on exactly one workload.
  hello_labels = {
    "app.kubernetes.io/name"    = "cline-hello"
    "app.kubernetes.io/part-of" = "cline-home"
  }
}
