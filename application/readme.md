
Hello! This readme documents the details on the k8s stack that I have been
working on and provides instructions on how to set it up. You are also welcome
to play around in the prototype that I am working in. Please see
using_the_prototype.md for details there


## This is my basic k8s at home stack. Features:

1. Self-Hosted Docker-Registry
2. Jenkins
3. certificate manager, with local CA service
4. openvpn 
5. cinc (for master and worker nodes)

## Coming features
5. confluence
6. wordpress
7. gitlab?

## Dependencies

1. The terraform-provider-k8s provider, for apply k8s manifests in K8s
``` #
   Build custom k8s provider git clone
   https://github.com/banzaicloud/terraform-provider-k8s.git
   cd terraform-provider-k8s go build go install

   # Add this  to ~/.terraformrc providers:
   { k8s = "/$GOPATH/bin/terraform-provider-k8s" }
```

2. You need to make a certficate and place them in ~/.ssl :
```
    export MYCN="linuxguru.net"
    mkdir ~/.ssl && cd ~/.ssl openssl genrsa -out ca.key 2048
    openssl req -x509 -new -nodes -key ca.key -subj "/CN=$MYCN" \
       -days 820 -reqexts v3_req -extensions v3_ca -out ca.crt
```

3. Do the terraform
```
tf apply
tf apply # a second time because of
         # https://github.com/banzaicloud/terraform-provider-k8s/issues/47
```

4. Enjoy!

# Known issues (Help needed!) 

##  Certificates

1. cert-manager automatically renews expiring certs for services, but the pods
   using certs typically have to be deleted so that a new pod can come up with
   the new certs

## Jenkins

1. Jenkins has a new  Configuration as Code that happily blows away any manual
   changes to the Jenkins stack. I'm still trying to figure out how to deal
   with that properly in a  tf+helm world.

