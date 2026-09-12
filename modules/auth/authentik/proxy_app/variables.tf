# Each key becomes the application/provider slug (sonarr, radarr, ...).
variable "apps" {
  type = map(object({
    external_host = string
    internal_host = string
    # Bookmark-tile icon URL shown in authentik's application list. Optional;
    # null leaves it unset (no icon).
    icon = optional(string)
  }))
}

variable "outpost_name" { default = "media-proxy" }
variable "group_name" { default = "media" }
