output "admin_group_id" {
  value = one(module.authentik_app[*].admin_group_id)
}

output "user_group_id" {
  value = one(module.authentik_app[*].user_group_id)
}
