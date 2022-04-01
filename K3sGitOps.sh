#!/bin/bash

# Assumption - CLI, Provider and extensions installed

#############################
# - Set Variables / Download OSM Client / Install OSM Extensions / Create Namespaces
#############################

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export appClonedRepo='https://github.com/zaidmohd/azure-arc-jumpstart-apps'
export resourceGroup='ArcBoxDevOps'
export arcClusterName='ArcBox-K3s'
export keyVaultName='kv-zc-9871'
export certname='ingress-cert'
export host='arcbox.devops.com'
export k3snamespace='k3s-hello-arc'

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Create GitOps config for Hello-Arc application
echo "Creating GitOps config for Hello-Arc application"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--namespace $k3snamespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=helloarc path=./hello-arc/yaml


################################################
# - Install Key Vault Extension / Create Ingress
################################################

echo "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name 'akvsecretsprovider' --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Create a namespace for your workload resources
kubectl create ns $k3snamespace

# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $k3snamespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $k3snamespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -n $k3snamespace -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync
spec:
  provider: azure
  secretObjects:   
    - secretName: dbusername
      type: Opaque
      data:
        - objectName: dbusername
          key: username
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: ""
    keyvaultName: "${keyVaultName}"
    objects: |
      array:
        - |
          objectName: dbusername             
          objectType: secret
          objectVersion: ""
    tenantId: "${tenantId}"
EOF

# Create the pod with volume referencing the secrets-store.csi.k8s.io driver
echo "Deploying App referencing the secret"
cat <<EOF | kubectl apply -n $k3snamespace -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox-secrets-sync
spec:
  containers:
  - name: busybox
    image: k8s.gcr.io/e2e-test-images/busybox:1.29
    env:
    - name: SECRET_USERNAME
      valueFrom:
        secretKeyRef:
          name: dbusername
          key: username
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
          secretProviderClass: "azure-kv-sync"
        nodePublishSecretRef:
          name: secrets-store-creds             
EOF

# Deploy an Ingress Resource referencing the Secret created by the CSI driver
echo "Deploying Ingress Resource"
cat <<EOF | kubectl apply -n $k3snamespace -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - $host
    secretName: ingress-tls-csi
  rules:
  - host: $host
    http:
      paths:
      - pathType: Prefix
        backend:
          service:
            name: $k3snamespace
            port:
              number: 14001
        path: /$k3snamespace
EOF