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

# Create GitOps config to deploy OSM Split Traffic Config
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-osm1 \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=split path=./scenarios/osm/split
