locals {
  labels = {
    "app.kubernetes.io/part-of"    = "cline-home"
    "app.kubernetes.io/managed-by" = "OpenTofu"
    "cline-home/owner"             = "cline"
  }

  # The hello deployment's selector.
  hello_labels = {
    "app.kubernetes.io/name"    = "cline-hello"
    "app.kubernetes.io/part-of" = "cline-home"
  }

  # The resident Cline's selector.
  resident_labels = {
    "app.kubernetes.io/name"    = "resident-cline"
    "app.kubernetes.io/part-of" = "cline-home"
  }
}
