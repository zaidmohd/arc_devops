#!/bin/bash

# Assumption - CLI, Provider and extensions installed

#############################
# - Set Variables / Download OSM Client / Install OSM Extensions / Create Namespaces
#############################

# <--- Change the following environment variables according to your Azure service principal name --->
# export appId='<Your Azure service principal name>'
# export password='<Your Azure service principal password>'
export tenantId='72f988bf-86f1-41af-91ab-2d7cd011db47'
export appClonedRepo='https://github.com/zaidmohd/arc_devops'
export resourceGroup='arc-capi-demo'
export arcClusterName='arc-capi-demo'
export osmRelease='v1.0.0'
export osmMeshName='osm'
export keyVaultName='kv-zc-9871'
export certname='ingress-cert'
export host='hello.azurearc.com'
export ingressNamespace='ingress-nginx'
export bookstoreVar='bookstore'
export bookbuyerVar='bookbuyer'
export bookstorev2Var='bookstore-v2'
export helloArcVar='hello-arc'

sed -i "s/{CERTNAME}/$certname/" KeyVault/*
sed -i "s/{KEYVAULTNAME}/$keyVaultName/" KeyVault/*
sed -i "s/{HOST}/$host/" KeyVault/*
sed -i "s/{TENANTID}/$tenantId/" KeyVault/*