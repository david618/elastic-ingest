#!/bin/bash

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
if [ "$#" -ge 3 ];then
  LOCATION=$2
fi

CORES=16
if [ "$#" -ge 4 ];then
  CORES=$3 
fi

if [[ "${CORES}" =~ ^(8|16|32|64)$ ]];then
  echo "Number Cores: ${CORES}"
else 
  echo "Invalid Cores Must be 8, 16, 32, or 64"
  exit 6
fi

COUNT=3
if [ "$#" -ge 3 ];then
  COUNT=$4
fi

echo "RG: ${RG}"
echo "CLUSTER: ${CLUSTER}"
echo "LOCATION: ${LOCATION}"
echo "SIZE: ${SIZE}"
echo "COUNT: ${COUNT}"

. ./support.sh ${RG}

update_status "Creating Tenant" 

log_msg "Creating AKS; this step can take up to 10 minutes"
./install-aks-10.sh ${RG} ${LOCATION} ${CORES} ${COUNT}
if [ "$?" -ne 0 ];then
	 update_status "Create Failed" 
	 exit 10
fi	

log_msg "Installing Portworx; this step can take up to 10 minutes"
./install-portworx-15.sh ${RG} 1024 
if [ "$?" -ne 0 ];then
	 update_status "Create Failed" 
	 exit 15
fi	

log_msg "Installing Datastore"
./install-datastore-es-20.sh ${RG} # mod
if [ "$?" -ne 0 ];then
	 update_status "Create Failed" 
	 exit 20
fi	

log_msg "Installing Gateway"
./install-gateway-kafka-30.sh ${RG}
if [ "$?" -ne 0 ];then
	 update_status "Create Failed"
	 exit 30
fi	

log_msg "Installing Spark Operator"
./install-sparkoperator-65.sh ${RG}
if [ "$?" -ne 0 ];then
	 update_status "Create Failed" 
	 exit 65
fi	

update_status "Install Completed"
log_msg "Install Completed"
