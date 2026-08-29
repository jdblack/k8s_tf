  ** This is a opentofu deployment. The state is stored in k8s **

These are deployments of wordpress sites. Each deployment is based off of
github.com/Linuxgurus/wordpress.git, which in turn contains a opentofu module
and a helm chart.  The helm chart contains wordpress, mariadb, service and load
balancer.

If you want to change the underlying code for these deployments, then you 
perform the following steps:

 - clone github.com/Linuxgurus/wordpress.git
 - Hack the terraform module and/or  helm chart in charts/
 - run ./build in the project root, which will:
   - update the version for the helm chart
   - commit and push the repo
   - package and push the chart 

