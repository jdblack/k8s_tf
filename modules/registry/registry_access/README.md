Tihs module puts a registry secret into a namespace where a deployment can
use them.  

Required inputs:

registry_ns:  The namspace the registry is in
registry_secret:  The secret that holds the registry auth

dest_ns:  The namespace to put the secret that deployments can use
dest_secret: The name of the scret to store the info


To use it, you specify the registry in the image for the container. E.G.


For example:


``
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myexample-deployment
  labels:
    app: myexample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myexample
  template:
    metadata:
      labels:
        app: myexample
    spec:
      containers:
      - name: myexample
        image: "${module.registry-puller.server}/myexample.14.2
        ports:
        - containerPort: 80
      imagePullSecrets:
      - name: "${local.registry_secret}"
```

