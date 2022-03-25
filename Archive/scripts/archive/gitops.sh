#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export appClonedRepo='https://github.com/zaidmohd/arc_devops'

# Create GitOps config to deploy application
echo "Creating GitOps config"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name cluster-config \
--cluster-type connectedClusters \
--scope cluster \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./app/yaml