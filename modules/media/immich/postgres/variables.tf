variable "namespace" { type = string }

# Names the deployment, service, secret and claim in one shot.
variable "name" { type = string }

variable "user" { default = "immich" }
variable "port" { default = 5432 }

variable "image" { default = "ghcr.io/immich-app/postgres" }

# VectorChord is not optional: the server refuses to boot without a supported version.
variable "image_tag" { default = "17-vectorchord0.4.3-pgvector0.8.0" }

variable "storage_class" { default = "longhorn" }
variable "size" { default = "20Gi" }

# VectorChord index maintenance wants more shm than the 64Mi default.
variable "shm_size" { default = "128Mi" }

variable "uid" { default = 1000 }
variable "gid" { default = 1000 }
