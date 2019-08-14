#!/bin/bash

set -e

if [ "$#" -lt 1 ];then
  echo "Usage: $0 [ResourceGroupName] "
  echo
  echo "Example: $0 dj0218"
  echo "Retrive Keys for dj0218 and put them in tenants folder."
  echo
  echo
  exit 4 
fi


az vm list -o table > /dev/null 2>&1
if [ $? -ne 0 ];then
  echo 'You need to login first. Run "az login"'
  exit 5 
fi


RG=$1
CLUSTER=${RG}-cluster

. ./support.sh ${RG}

az aks get-credentials --subscription ${SID} --resource-group ${RG} --name ${CLUSTER} --overwrite-existing -f ${KC}
az aks get-credentials --subscription ${SID} --resource-group ${RG} --name ${CLUSTER} --overwrite-existing

