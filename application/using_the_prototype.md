# Using the prototype stack

## SSL Setup

LG has a local CA for all this fun stuff. You can make life easier if you trust
me, and by proxy the CA. You can alternatively work around it by deling with
"unsecured site" warnings in chrome, set unsecured_registry in your
docker.json, etc etc

1. Download the LG cert:
wget https://for-your-perusal.s3.amazonaws.com/ssl_certs/linuxguru.crt
2. On macs run "open linuxguru.crt". This will open your keychain apps and import the LG ca cert.
3. Double click the Linuxguru cert,select "|> Trust and select "Always Trust"
4. The cert will -not- work until you log out and back in
5. Tell knife to cut you a openvpn config

## VPN Setup

I have set up a VPN that will bridge you into my network, granting full local
access as if you were hooked up internally.  The VPN also forwards DNS
addresses, allowing you to curl https://registry:5000,  http://jenkins and
so on. LoadBalancer services will show up in 192.168.1.50-19.168.1.99. DNS
is manually managed for now on an OpenWRT router

1. Install an openvpn client. I personally use tunnelblick
2. Click the tunnelblick icon and select "vpn details"
3. Set  "Set DNS/WINS to  "Set nameserver"
4. Turn off "Route all IPv4 traffic through VPN" 
5. Find the openvpn conf I sent you and use finder to drag the openvpn conf onto the tunnelblick config
6. You should be able to connect now


## K8s setup

1. You can have access to this, but I haven't sorted out accounts stuff yet

