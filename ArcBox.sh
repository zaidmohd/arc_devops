#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export appClonedRepo='https://github.com/zaidmohd/azure-arc-jumpstart-apps'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export osmRelease='v1.0.0'
export osmMeshName='osm'
export ingressNamespace='ingress-nginx'
export keyVaultName='kv-zc-9871'
export certname='ingress-cert'
export host='arcbox.devops.com'

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# "Download OSM binaries"
curl -L https://github.com/openservicemesh/osm/releases/download/${osmRelease}/osm-${osmRelease}-linux-amd64.tar.gz | tar -vxzf -

# "Copy the OSM binary to local bin folder"
sudo cp ./linux-amd64/osm /usr/local/bin/osm

# "Create OSM Kubernetes extension instance"
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --name $osmMeshName

# Create Kubernetes Namespaces
for namespace in bookstore bookbuyer bookwarehouse hello-arc ingress-nginx
do
kubectl create namespace $namespace
done

# Add the bookstore namespaces to the OSM control plane
osm namespace add bookstore bookbuyer bookwarehouse

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace. 
# However, Nginx must NOT be injected with an Envoy sidecar to function properly.
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
echo "Creating GitOps config for Bookstore application"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-bookstore \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=bookstore path=./bookstore/yaml

# Create GitOps config for Bookstore RBAC
echo "Creating GitOps config for Bookstore RBAC"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-bookstore-rbac \
--cluster-type connectedClusters \
--scope namespace \
--namespace bookstore \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=bookstore path=./bookstore/rbac-sample

# Create GitOps config for Bookstore Traffic Split
echo "Creating GitOps config for Bookstore Traffic Split"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-bookstore-osm \
--cluster-type connectedClusters \
--scope namespace \
--namespace bookstore \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=bookstore path=./bookstore/osm-sample

# Create GitOps config for Hello-Arc application
echo "Creating GitOps config for Hello-Arc application"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--namespace hello-arc \
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
openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $certname.pfx -passout pass:

# <Placeholder>
# Need to add command to install this certificate on the ArcBox Client VM
#

echo "Importing the TLS certificate to Key Vault"
az keyvault certificate import --vault-name $keyVaultName -n $certname -f $certname.pfx
 
echo "Installing Azure Key Vault Kubernetes extension instance"
az k8s-extension create --name 'akvsecretsprovider' --extension-type Microsoft.AzureKeyVaultSecretsProvider --scope cluster --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --release-train preview --release-namespace kube-system --configuration-settings 'secrets-store-csi-driver.enableSecretRotation=true' 'secrets-store-csi-driver.syncSecret.enabled=true'

# Replace Variable values
sed -i "s/{JS_CERTNAME}/$certname/" KeyVault/*
sed -i "s/{JS_KEYVAULTNAME}/$keyVaultName/" KeyVault/*
sed -i "s/{JS_HOST}/$host/" KeyVault/*
sed -i "s/{JS_TENANTID}/$tenantId/" KeyVault/*

# Deploy Ingress resources for Bookstore and Hello-Arc App
for namespace in bookstore bookbuyer hello-arc
do
# Create the Kubernetes secret with the service principal credentials
kubectl create secret generic secrets-store-creds --namespace $namespace --from-literal clientid=${appId} --from-literal clientsecret=${password}
kubectl --namespace $namespace label secret secrets-store-creds secrets-store.csi.k8s.io/used=true

# Deploy Key Vault resources and Ingress for Book Store and Hello-Arc App
kubectl --namespace $namespace apply -f KeyVault/$namespace.yaml

done
