variable "namespace" { type = string }

# Names the deployment, service and claim in one shot.
variable "name" { type = string }

variable "image" { default = "valkey/valkey" }
variable "image_tag" { default = "9-alpine" }

variable "port" { default = 6379 }

# The uid the valkey image ships with.
variable "uid" { default = 999 }
variable "gid" { default = 999 }
