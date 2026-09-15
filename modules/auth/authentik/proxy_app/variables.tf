# Each key becomes the application/provider slug (sonarr, radarr, ...).
variable "apps" {
  type = map(object({
    external_host = string
    internal_host = string
    # Bookmark-tile icon URL; null leaves it unset.
    icon = optional(string)
  }))
}

variable "outpost_name" { default = "media-proxy" }
variable "group_name" { default = "media" }
