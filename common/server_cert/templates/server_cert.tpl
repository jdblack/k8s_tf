apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: ${name}
spec:
  secretName: ${name}
  commonName: ${commonname}
  duration: 2160h 
  renewBefore: 720h
  keyAlgorithm: rsa
  keyEncoding: pkcs1
  usages:
    - server auth
    - client auth
  dnsNames:
%{ for s in hostnames ~}
  - ${s}
%{ endfor ~}
  issuerRef:
    name: ${issuer}
    kind: ClusterIssuer

