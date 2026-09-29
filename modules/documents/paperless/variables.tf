variable "namespace" { type = string }

# Names the deployment, service, config map and secret in one shot.
variable "name" { type = string }

# The probes have to present this Host, or Django rejects them.
variable "hostname" { type = string }

variable "image" { default = "ghcr.io/paperless-ngx/paperless-ngx" }

# ghcr tags carry no 'v', unlike the GitHub release names.
variable "image_tag" { default = "3.2.1" }

variable "port" { default = 8000 }
variable "flower_port" { default = 5555 }
variable "flower_enabled" { default = true }

variable "data_pvc" { type = string }
variable "media_pvc" { type = string }
variable "consume_pvc" { type = string }

variable "admin_user" { type = string }
variable "admin_mail" { type = string }

variable "time_zone" { default = "Asia/Ho_Chi_Minh" }

variable "ocr_language" { default = "eng+vie" }

# Installable at container start, which the image does with apt and therefore as root.
variable "ocr_languages" { default = "vie" }

variable "filename_format" {
  type    = string
  default = null
}

# Everything the caller decides: broker address, URL, OIDC, AI. Keys land in the config map.
variable "extra_config" {
  type    = map(string)
  default = {}
}

# Same, for the secret; the caller owns anything it does not want readable.
variable "extra_secret" {
  type    = map(string)
  default = {}
}

variable "uid" { default = 1000 }
variable "gid" { default = 1000 }
