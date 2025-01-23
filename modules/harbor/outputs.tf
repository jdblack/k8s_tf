

output registry_host { value = local.fqdn }
output registry_url { value = local.url }
output admin_pass { value = random_password.admin_password.result }
