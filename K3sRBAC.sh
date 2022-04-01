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
export arcClusterName='ArcBox-CAPI-Data'
export osmRelease='v1.0.0'
export osmMeshName='osm'
export ingressNamespace='ingress-nginx'
export keyVaultName='kv-zc-9871'
export certname='ingress-cert'
export host='arcbox.devops.com'

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

#############################
# - Apply GitOps Configs
#############################

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
