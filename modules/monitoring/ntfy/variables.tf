variable "name" { default = "ntfy" }
variable "namespace" {}
variable "domain" {}
variable "cert_issuer" {}

# The shared public gateway (kube-network). The phone and Alertmanager are
# non-browser API clients, so this app is NOT put behind the authentik proxy
# outpost -- an SSO redirect is something neither can complete. ntfy's own auth
# (deny-all + tokens) is what protects the data.
variable "gateway_name" { default = "public" }
variable "gateway_namespace" { default = "kube-network" }

# The topic the alerting publisher writes to, and the ACL is scoped to.
variable "alert_topic" { default = "alerts" }

# Break-glass admin. Provisioned in the config file so there is always a way in:
# the web UI cannot create an admin (signup hardcodes role=user), and the admin
# API cannot create the *first* admin either. Humans live in the mantle stack
# (modules/monitoring/ntfy_users) and are created against the running server.
variable "admin_user" { default = "ntfyadmin" }

# The alerting publisher. Deliberately NOT the admin: ntfy access tokens grant
# FULL access to the user account, so an admin's token mounted into Alertmanager
# would be a full-admin credential. This one is a plain user with write-only on
# a single topic.
variable "publisher_user" { default = "alertmanager" }

variable "storage_class" { default = "longhorn" }
variable "storage_size" { default = "1Gi" }

# Alertmanager's webhook body is its full alert JSON. Bodies >= this limit are
# NOT truncated: ntfy routes them to the attachment path, which fails with HTTP
# 400 "attachments not allowed" when no attachment backend is configured. So a
# multi-alert incident would silently not arrive. 64K covers realistic batches
# (the docs caution that >4K is "largely untested", but that warning is aimed at
# the FCM/APNS payload caps, neither of which is used here).
variable "message_size_limit" { default = "64K" }
