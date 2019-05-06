#!/bin/bash

set -e

if [ "$#" -lt 1 ];then
  echo "Usage: $0 [ResourceGroupName] (Location=eastus2) (cores-per-node=16) (number-nodes=6)"
  echo
  echo "Example: $0 dj0218"
  echo "This will create the resource group dj0218 and AKS dj0218-cluster, in eastus2, creating 6 nodes with 16 cores each."
  echo
  echo "Example: $0 dj0218 westus2 32 12"
  echo "This will create the resource group dj0218 and AKS dj0218-cluster, in westus2, creating 12 nodes with 32 cores each."
  echo
  exit 4 
fi


az vm list -o table > /dev/null 2>&1
if [ $? -ne 0 ];then
  echo 'You need to login first. Run "az login"'
  exit 5 
fi

# We could use a parameter based on tenant (small, standard, large)

RG=$1
CLUSTER=${RG}-cluster

LOCATION=eastus2
if [ "$#" -ge 2 ];then
  LOCATION=$2
fi

CORES=16
if [ "$#" -ge 3 ];then
  CORES=$3 
fi

if [[ "${CORES}" =~ ^(8|16|32|64)$ ]];then
  echo "Number Cores: ${CORES}"
else 
  echo "Invalid Cores Must be 8, 16, 32, or 64"
  exit 6
fi

SIZE=Standard_D${CORES}s_v3

COUNT=6
if [ "$#" -ge 4 ];then
  COUNT=$4
fi

echo "RG: ${RG}"
echo "CLUSTER: ${CLUSTER}"
echo "LOCATION: ${LOCATION}"
echo "SIZE: ${SIZE}"
echo "COUNT: ${COUNT}"

# Creates KC
. ./support.sh ${RG}

update_url ""
update_a4iot_build ""

echo "Checking Resource Limits"

USER=azureuser
PUBKEY=az.pub

# Check cores available
DSV3USED=$(az vm list-usage --location ${LOCATION} -o tsv |  awk -F'\t' '/DSv3/ {print $1}')
DSV3LIMIT=$(az vm list-usage --location ${LOCATION} -o tsv |  awk -F'\t' '/DSv3/ {print $2}')
DSV3AVAIL=$((${DSV3LIMIT}-${DSV3USED}))

CORESREQ=$((${CORES}*${COUNT}))
if [ "${CORESREQ}" -gt "${DSV3AVAIL}" ]; then
   log_msg "Insufficient cores in ${LOCATION}. This request requires: ${CORESREQ}"
   log_msg "There are ${DSV3AVAIL} DSv3 cores available in ${LOCATION}"
   exit 7 
fi
  
echo "Creating Resource Group"
az group create --name ${RG} --location ${LOCATION}

# Right now hard-coded root disk of 100G and K8S version 1.12.7 

echo "Creating AKS"

start=$(date +'%s')
az aks create \
    --resource-group ${RG} \
    --name ${CLUSTER} \
    --node-count ${COUNT} \
    --node-vm-size ${SIZE} \
    --enable-addons monitoring \
    --admin-username ${USER} \
    --ssh-key-value ${PUBKEY} \
    --node-osdisk-size 100 \
    --kubernetes-version 1.12.7 
echo "It took $(($(date +'%s') - $start)) seconds to create AKS"

echo "Getting AKS Credentials"

az aks get-credentials --resource-group ${RG} --name ${CLUSTER} --overwrite-existing -f ${KC}
az aks get-credentials --resource-group ${RG} --name ${CLUSTER} --overwrite-existing 

# Dashboard Access
echo "Setting service account to allow access to K8s Dashboard"
kubectl --kubeconfig=${KC} create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

echo "You can now access dashboard using command: az aks browse --resource-group ${RG} --name ${CLUSTER}"

# Helm
echo "Initializing Helm"

helm --kubeconfig=${KC} init
kubectl --kubeconfig=${KC} create serviceaccount --namespace kube-system tiller
kubectl --kubeconfig=${KC} create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl --kubeconfig=${KC} patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

echo "It took $(($(date +'%s') - $start)) seconds to deploy AKS"



