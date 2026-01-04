
variable namespace { type = string } 
variable allow_internet { default = false }
variable allow_dns { default = true }

locals {

	from_namespace = {
		from = [
			{
				namespaceSelector = {
					matchLabels = { "kubernetes.io/metadata.name" = var.namespace }
				}
				podSelector = {}
			}
		]
	}
	to_namespace = {
		to = [
			{
				namespaceSelector = {
					matchLabels = { "kubernetes.io/metadata.name" = var.namespace }
				}
				podSelector = {}
			}
		]
	}
	to_internet = {
		to = [
			{
				ipBlock = {
					cidr = "0.0.0.0/0"
					except = [ "10.0.0.0/8" ]
				}
			}
		]
	}

	to_dns = {
		to = [
			{
				namespaceSelector = {
					matchLabels = {
						"kubernetes.io/metadata.name" = "kube-system"
					}
				}
				podSelector = {
					matchLabels = { "k8s-app" = "kube-dns" }
				}
			}
		]
		ports = [
			{
				protocol = "UDP"
				port = 53
			}
		]
	}


}

