#!/bin/bash
kubectl --kubeconfig kubeconfig* create -f  - <<END
apiVersion: v1
kind: Secret
metadata:
  name: mongo-sensor-cache-secret
  namespace: nanoprecise
type: Opaque
data:
  MONGO_AUTH_PASS: $(dd if=/dev/urandom count=200 bs=1 2>/dev/null | tr -dc _A-Z-a-z-0-9 | tr -d '\n' | cut -c-18| tr -d '\n' | base64 )
stringData:
  MONGO_USERNAME: admin
  MONGO_AUTH_DB: admin
  MONGODB_RS_NAME: rs0
  MONGO_HOST: mongo
  mongo-sensor-cachedb-keyfile: $(openssl rand -base64 741 | tr -d "\n")
END
