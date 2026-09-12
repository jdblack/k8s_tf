terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
    # Bcrypt hashes for the config-provisioned service accounts. ntfy's
    # auth-users goes through ValidPasswordHash(), which rejects anything that
    # is not a real $2a$/$2b$/$2y$ bcrypt hash -- there is no plaintext path for
    # config provisioning. A managed *resource* (not a data source) matters:
    # bcrypt salts are random, so a data source recomputing each plan would
    # churn the secret forever.
    htpasswd = {
      source = "loafoe/htpasswd"
    }
  }
}
