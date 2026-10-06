output "admin_group_id" {
  value = authentik_group.admin.id
}

output "user_group_id" {
  value = authentik_group.user.id
}
