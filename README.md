# Kubernetes Terraform

This deployment is split into three stacks due to certain terraform limitations
involving providers.  Terraform is unable to create a provider for a service
that it has just built.  For example, consider Keycloak, which is created with
the Helm provider, but then configured with the Keycloak provider. The
Keycloak provider can not exist until after the helm provider has finished.

To deal with this, we have three stack directories, each of which needs
to be deployed independently with `terraform apply`.

## Layout

```
stacks/
├── core/     # infrastructure foundation (network, storage, certs, platform services)
├── mantle/   # workload layer (media, harbor/argo config, blender)
└── apps/     # ArgoCD app-of-apps (ai, websites)
```

## Deployment Order

1. **`stacks/core/`** — deploys the base infrastructure: network, storage,
   cert-manager, auth, and devops platform services (Harbor, ArgoCD).
2. **`stacks/mantle/`** — deploys workloads on top: media stack, harbor/argo
   configuration, and blender.
3. **`stacks/apps/`** — deploys applications via ArgoCD app-of-apps.

Each stack uses a Kubernetes secret backend with a distinct `secret_suffix`
(`core`, `mantle`, `deployment`) to keep state separate.