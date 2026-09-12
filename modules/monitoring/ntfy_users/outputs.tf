output "secret_name" {
  # One Secret holds every user's generated password; null when no users are
  # configured (and therefore no Secret is created).
  value = try(kubernetes_secret_v1.users[0].metadata[0].name, null)
}

output "usernames" {
  value = sort(keys(var.users))
}
