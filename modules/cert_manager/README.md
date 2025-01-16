

Installation:


This module performs two things:  A local CA for inhouse tools, and  Lets
Encrypt for public facting things. First, let's set up the inside:

## Setting up the local CA

1. You'll need a CA certificate  (Of one year) to do this. To create that, 
start up an ubuntu container and install openssl to create the ca-key and
ca-cert.

```
#First, generate the key:

openssl genrsa -out ca-key.pem 4096

# Next, genrate the cert:
openssl req -x509 -new -nodes -key ca-key.pem -sha256 -days 365 -out ca-cert.pem

```

Now, drop both in ~/.ssl/ca.crt and ~/.ssh/ca.key  on the compuer that 
runs terraform, as the certmanager tf will provide theem to certman.




