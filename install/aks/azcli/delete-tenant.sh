#!/bin/bash

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
	  --subscription ${SID} \
    --name ${CLUSTER} \
    --resource-group ${RG} \
    --yes 

log_msg "Deleting the Resource Group"

az group delete --subscription ${SID} --name ${RG} --yes

log_msg "Deleting Service Principal"

# Delete Service Principal; Subscription ID (SID) comes from support.sh
APPID=$(az ad sp list --subscription ${SID} --display-name ${RG} | jq --raw-output '.[0].appId')
az ad sp delete --id ${APPID} --subscription ${SID}

if [ "$?" -ne 0 ]; then
  log_msg "Service Principal Delete failed; this is expected, if you were not the person who created the tenant. "
fi

echo "Delete completed. It took $(($(date +'%s') - $start)) seconds"
log_msg "Delete Completed"
update_status "Delete Completed" 

