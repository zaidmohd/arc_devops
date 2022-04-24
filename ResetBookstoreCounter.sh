#!/bin/bash

export host='arcbox.devops.com'

############################
# - Deploy Ingress for Reset
############################

# Deploy Ingress for Bookbuyer Reset API 
echo "Deploying Ingress Resource for bookbuyer"
cat <<EOF | kubectl apply -n bookbuyer -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-reset-bookbuyer
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /reset
spec:
  tls:
  - hosts:
    - "${host}"
    secretName: ingress-tls-csi
  rules:
  - host: "${host}"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookbuyer
            port:
              number: 14001
        path: /bookbuyer/reset
EOF

# Deploy Ingress for Bookstore Reset API 
echo "Deploying Ingress Resource for bookstore"
cat <<EOF | kubectl apply -n bookstore -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-reset-bookstore
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /reset
spec:
  tls:
  - hosts:
    - "${host}"
    secretName: ingress-tls-csi
  rules:
  - host: "${host}"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookstore
            port:
              number: 14001
        path: /bookstore/reset
EOF

# Deploy Ingress for Bookstore-v2 Reset API 
echo "Deploying Ingress Resource for bookstore-v2"
cat <<EOF | kubectl apply -n bookstore -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-reset-bookstore-v2
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /reset
spec:
  tls:
  - hosts:
    - "${host}"
    secretName: ingress-tls-csi
  rules:
  - host: "${host}"
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookstore-v2
            port:
              number: 14001
        path: /bookstore-v2/reset
EOF

####################
# - Invoke Reset API
####################

curl -k https://${host}/bookbuyer/reset &

curl -k https://${host}/bookstore/reset &

curl -k https://${host}/bookstore-v2/reset &