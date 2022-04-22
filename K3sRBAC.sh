#!/bin/bash

# <--- Change the following environment variables according to your Azure service principal name --->
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export appClonedRepo='https://github.com/zaidmohd/azure-arc-jumpstart-apps'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export k3sNamespace='hello-arc'

# <Placeholder>
# Connect to K3s Cluster
#kubectl config set-context arcboxk3s

# echo "Login to Az CLI using the service principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

#############################
# - Apply GitOps Configs
#############################

# Create GitOps config for Hello-Arc RBAC
echo "Creating GitOps config for Hello-Arc RBAC"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc-rbac \
--cluster-type connectedClusters \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=bookstore path=./k8s-rbac-sample
