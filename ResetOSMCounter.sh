#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export appClonedRepo='https://github.com/zaidmohd/azure-arc-jumpstart-apps'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export keyVaultName='kv-zc-9871'
export k3sCertName='k3s-ingress-cert'
export host='arcbox.k3sdevops.com'
export k3sNamespace='hello-arc'
export ingressNamespace='ingress-nginx'

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
        path: /reset
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
        path: /reset
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
        path: /reset
EOF



####################
# - Invoke Reset API
####################


# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -n $k3sNamespace -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync-tls
spec:
  provider: azure
  secretObjects:                       # secretObjects defines the desired state of synced K8s secret objects                                
  - secretName: ingress-tls-csi
    type: kubernetes.io/tls
    data: 
    - objectName: "${k3sCertName}"
      key: tls.key
    - objectName: "${k3sCertName}"
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    keyvaultName: ${keyVaultName}                        
    objects: |
      array:
        - |
          objectName: "${k3sCertName}"
          objectType: secret
    tenantId: "${tenantId}"
EOF

# Create the pod with volume referencing the secrets-store.csi.k8s.io driver
echo "Deploying App referencing the secret"
cat <<EOF | kubectl apply -n $k3sNamespace -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-secrets-sync
spec:
  containers:
  - name: busybox
    image: k8s.gcr.io/e2e-test-images/busybox:1.29
    command:
      - "/bin/sleep"
      - "10000"
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
    - name: secrets-store-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kv-sync-tls"
        nodePublishSecretRef:
          name: secrets-store-creds           
EOF

# Deploy an Ingress Resource referencing the Secret created by the CSI driver
echo "Deploying Ingress Resource"
cat <<EOF | kubectl apply -n $k3sNamespace -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
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
            name: hello-arc
            port:
              number: 8080
EOF