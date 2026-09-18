variable "namespace" { default = "media" }
variable "name" { default = "unpackerr" }

variable "image" { default = "ghcr.io/unpackerr/unpackerr" }
variable "image_tag" { default = "v0.16.1" }

variable "movies_pvc" { type = string }

variable "mount_path" { default = "/media" }

variable "downloads_path" {
  type    = string
  default = null
}

variable "sonarr_url" { default = "http://sonarr:80" }
variable "radarr_url" { default = "http://radarr:80" }

variable "sonarr_api_key" {
  type      = string
  sensitive = true
  default   = ""

  validation {
    condition     = var.sonarr_api_key == null || var.sonarr_api_key == "" || length(var.sonarr_api_key) >= 32
    error_message = "sonarr_api_key is empty (Sonarr is skipped) or the 32-character <ApiKey> from sonarr's /config/config.xml."
  }
}

variable "radarr_api_key" {
  type      = string
  sensitive = true
  default   = ""

  validation {
    condition     = var.radarr_api_key == null || var.radarr_api_key == "" || length(var.radarr_api_key) >= 32
    error_message = "radarr_api_key is empty (Radarr is skipped) or the 32-character <ApiKey> from radarr's /config/config.xml."
  }
}
