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

# <Placeholder>
# Need to connect to K3s Cluster
#

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

#############################
# - Apply GitOps Configs
#############################

# Create GitOps config for NGINX Ingress Controller
echo "Creating GitOps config for NGINX Ingress Controller"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-nginx \
--namespace $ingressNamespace \
--cluster-type connectedClusters \
--scope cluster \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=nginx path=./nginx/release

# Create GitOps config for Hello-Arc application
echo "Creating GitOps config for Hello-Arc application"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--namespace $k3sNamespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=helloarc path=./hello-arc/yaml


################################################
# - Install Key Vault Extension / Create Ingress
################################################

echo "Generating a TLS Certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress-tls.key -out ingress-tls.crt -subj "/CN=${host}/O=${host}"
openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $k3sCertName.pfx -passout pass:

# <Placeholder>
# Need to add command to install this certificate on the ArcBox Client VM
#

# <Placeholder>
# Checking if Ingress Controller is ready and create Host file entry
until kubectl get service/ingress-nginx-controller --namespace $ingressNamespace --output=jsonpath='{.status.loadBalancer}' | grep "ingress"; do echo "Waiting for NGINX Ingress controller external IP..." && sleep 20 ; done


echo "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $keyVaultName -n $k3sCertName -f $k3sCertName.pfx
 
echo "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name 'akvsecretsprovider' --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Create a namespace for your workload resources
kubectl create ns $k3sNamespace

# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $k3sNamespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $k3sNamespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

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