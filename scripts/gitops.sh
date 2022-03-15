#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export appClonedRepo='https://github.com/zaidmohd/arc_devops'

# Installing Azure CLI
echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Installing required Azure Arc CLI extensions
az extension add --name connectedk8s
az extension add --name k8s-configuration

# Login to Azure
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Registering Azure Arc providers
echo "Registering Azure Arc providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table

# Create a namespace for your App resources
kubectl create namespace bookstore
kubectl create namespace bookbuyer
kubectl create namespace bookthief
kubectl create namespace bookwarehouse

# Add the new namespaces to the OSM control plane
osm namespace add bookstore bookbuyer bookthief bookwarehouse

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