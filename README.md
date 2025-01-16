
This deployment is split into two parts due to certain terraform limitations involving providers.  Terraform
is unable to create a provider for a service that is has just built.  For example,  consider Keycloak, which is
created with the Helm provider,  but then  configured with the Keycloak provider.   The  Keycloak provider can not
exist until after the helm provider has finished.

