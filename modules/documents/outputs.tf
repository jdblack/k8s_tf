output "fqdn" {
  value = module.owncloud.fqdn
}

output "onlyoffice_fqdn" {
  value = module.onlyoffice.fqdn
}

output "s3_secret_name" {
  value = module.owncloud.s3_secret_name
}

output "owncloud_admin_group_id" {
  value = module.owncloud.admin_group_id
}

output "owncloud_user_group_id" {
  value = module.owncloud.user_group_id
}
