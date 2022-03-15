#!/bin/bash

# Setup Cluster - Install NGINX Controller, Download OSM client, Install OSM extension, Add namespace to OSM
# Assumption - CLI, Provider and extensions installed

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export osmRelease=v1.0.0
export osmMeshName='osm'
export ingressNamespace='ingress-nginx'

# echo "Login to Az CLI using the service principal"
# az login --service-principal --username $appId --password $password --tenant $tenantId

# Install NGINX Ingress Controller using HELM
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace $ingressNamespace --create-namespace

# "Download OSM binaries"
curl -L https://github.com/openservicemesh/osm/releases/download/${release}/osm-${release}-linux-amd64.tar.gz | tar -vxzf -

# "Copy the OSM binary to local bin folder"
sudo cp ./linux-amd64/osm /usr/local/bin/osm

# "Create OSM Kubernetes extension instance"
# az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $k8sOSMExtensionName --release-namespace arc-osm-system --version $osmVersion
az k8s-extension create --cluster-name $arcClusterName --resource-group $resourceGroup --cluster-type connectedClusters --extension-type Microsoft.openservicemesh --scope cluster --release-train pilot --name $osmMeshName --version $osmRelease

# To be able to discover the endpoints of this service, we need OSM controller to monitor the corresponding namespace. However, Nginx must NOT be injected with an Envoy sidecar to function properly.
osm namespace add "$nginx_ingress_namespace" --mesh-name "$osmMeshName" --disable-sidecar-injection