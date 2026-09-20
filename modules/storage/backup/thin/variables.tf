variable "name" { default = "backup-thin" }
variable "namespace" { default = "kube-backup" }

# After the 03:00 dailies, before anyone needs to read yesterday's chain.
variable "schedule" { default = "0 6 * * *" }
variable "image" { default = "docker.io/alpine/k8s:1.35.0" }

# Ships dry: the plan is printed to the job log, nothing is deleted.
variable "dry_run" { type = bool }

variable "max_deletions" { default = 50 }
