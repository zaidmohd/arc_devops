#!/bin/bash

# Assumption - CLI, Provider and extensions installed

#############################
# - Set Variables / Download OSM Client / Install OSM Extensions / Create Namespaces
#############################

# <--- Change the following environment variables according to your Azure service principal name --->
# export appId='<Your Azure service principal name>'
# export password='<Your Azure service principal password>'
# export tenantId='<Your Azure tenant ID>'

export appClonedRepo='https://github.com/zaidmohd/arc_devops'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export osmRelease='v1.0.0'
export osmMeshName='osm'
export ingressNamespace='ingress-nginx'
export k8sKVExtensionName='akvsecretsprovider'
export keyVaultName='kv-zc-9871'
export certname='ingress-cert'
export host='hello.azurearc.com'

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# "Download OSM binaries"
curl -L https://github.com/openservicemesh/osm/releases/download/${osmRelease}/osm-${osmRelease}-linux-amd64.tar.gz | tar -vxzf -

# "Copy the OSM binary to local bin folder"
sudo cp ./linux-amd64/osm /usr/local/bin/osm

# "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $osmMeshName

# Create namespace for NGINX Ingress Controller
kubectl create namespace $ingressNamespace

# Create namespaces for your App resources
for namespace in bookstore bookbuyer bookwarehouse hello-arc
do
kubectl create namespace $namespace
done

# Add the bookstore namespaces to the OSM control plane
osm namespace add bookstore bookbuyer bookwarehouse

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace. However, Nginx must NOT be injected with an Envoy sidecar to function properly.
osm namespace add "$ingressNamespace" --mesh-name "$osmMeshName" --disable-sidecar-injection


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

# Create GitOps config for Bookstore application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-bookstore \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=bookstore path=./app/bookstore

# Create GitOps config for deploy Hello-Arc application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=helloarc path=./app/hello-arc


#############################
# - Install Key Vault Extension / Create Ingress
#############################

echo "Generating a TLS Certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress-tls.key -out ingress-tls.crt -subj "/CN=${host}/O=${host}"
openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $certname.pfx -passout pass:
 
echo "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $keyVaultName -n $certname -f $certname.pfx
 
echo "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name $k8sKVExtensionName --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Deploy Secret Provider Class, Sample pod, App pod and Ingress for app namespace (bookstore bookbuyer)
for namespace in bookstore bookbuyer
do

# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true
 
# Deploy SecretProviderClass
echo "Creating Secret Provider Class"
cat <<EOF | kubectl apply -n $namespace -f -
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
    - objectName: $certname
      key: tls.key
    - objectName: $certname
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    keyvaultName: $keyVaultName                        
    objects: |
      array:
        - |
          objectName: $certname
          objectType: secret
    tenantId: $tenantId           
EOF
 
# Create Sample pod with volume referencing the secrets-store.csi.k8s.io driver
echo "Deploying App referencing the secret"
cat <<EOF | kubectl apply -n $namespace -f -
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
cat <<EOF | kubectl apply -n $namespace -f -
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
      - pathType: ImplementationSpecific
        backend:
          service:
            name: $namespace
            port:
              number: 14001
        path: /$namespace
EOF

# To restrict ingress traffic on backends to authorized clients, 
# we will set up the IngressBackend configuration such that only 
# ingress traffic from the endpoints of the Nginx Ingress Controller 
# service can route traffic to the service backend.

cat <<EOF | kubectl apply -n $namespace -f -
kind: IngressBackend
apiVersion: policy.openservicemesh.io/v1alpha1
metadata:
  name: backend
spec:
  backends:
  - name: $namespace
    port:
      number: 14001
      protocol: http
  sources:
  - kind: Service
    namespace: ingress-nginx
    name: ingress-nginx-controller
EOF

done

# Create Ingress secret for Bookstore-v2 app
for namespace in bookstore
do
# Deploy an Ingress Resource referencing the Secret created by the CSI driver
echo "Deploying Ingress Resource"
cat <<EOF | kubectl apply -n $namespace -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls-bookstore-v2
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
      - pathType: ImplementationSpecific
        backend:
          service:
            name: bookstore-v2
            port:
              number: 14001
        path: /bookstore-v2
EOF

# To restrict ingress traffic on backends to authorized clients, 
# we will set up the IngressBackend configuration such that only 
# ingress traffic from the endpoints of the Nginx Ingress Controller 
# service can route traffic to the service backend.

cat <<EOF | kubectl apply -n $namespace -f -
kind: IngressBackend
apiVersion: policy.openservicemesh.io/v1alpha1
metadata:
  name: backend-bookstore-v2
spec:
  backends:
  - name: bookstore-v2
    port:
      number: 14001
      protocol: http
  sources:
  - kind: Service
    namespace: ingress-nginx
    name: ingress-nginx-controller
EOF

done