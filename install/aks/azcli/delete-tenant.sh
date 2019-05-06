#!/bin/bash

set -e

if [ "$#" -ne 1 ];then
  echo "Usage: $0 [ResourceGroupName]"
  echo "Example: $0 dj0218"
  echo "This will delete AKS dj0218-cluster; then delete the dj0218 resource group"
  exit 99
fi

start=$(date +'%s')

RG=$1
CLUSTER=${RG}-cluster

. ./support.sh ${RG}

update_url ""
update_a4iot_build "${A4IOT_BUILD_NUM}"

update_status "Deleting Tenant"

log_msg "Deleting AKS. This can take 10 minutes."

az aks delete \
    --name ${CLUSTER} \
    --resource-group ${RG} \
    --yes 

log_msg "Deleting the Resource Group"

az group delete --name ${RG} --yes

echo "Delete completed. It took $(($(date +'%s') - $start)) seconds"
log_msg "Delete Completed"
update_status "Delete Completed" 

