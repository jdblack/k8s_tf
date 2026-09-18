locals {
  downloads_path = coalesce(var.downloads_path, var.mount_path)
}
