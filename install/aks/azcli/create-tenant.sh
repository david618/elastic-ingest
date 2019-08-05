#!/bin/bash

if [ "$#" -lt 2 ];then
	echo "Usage: $0 [ResourceGroupName] (Location=eastus2) (cores-per-node=16|32) (number-nodes=6) (aks-type=default|advnet|aci) (clouddrives=yes|no|nopx)"
  echo
  echo "Example: $0 dj0219 westus2 16 6 aci yes"
  echo "Create Resource Group dj0219; AKS dj0219-cluster, in westus2, creating 6 nodes; 16 per node; aci enabled; portworx cloud drives"
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
CLUSTER="${RG}-cluster"

LOCATION="eastus2"
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

COUNT=6
if [ "$#" -ge 4 ];then
  COUNT=$4
fi

DEV="no"

AKS_TYPE="default"
if [ "$#" -ge 5 ];then
  AKS_TYPE=$5
fi

CLOUDDRIVES="yes"
if [ "$#" -ge 6 ];then
  CLOUDDRIVES=$6
fi

echo "RG: ${RG}"
echo "CLUSTER: ${CLUSTER}"
echo "LOCATION: ${LOCATION}"
echo "SIZE: ${SIZE}"
echo "COUNT: ${COUNT}"
echo "CLOUDDRIVES: ${CLOUDDRIVES}"

. ./support.sh ${RG}

update_status "Creating Tenant" 

log_msg "Creating AKS; this step can take up to 10 minutes"
if [ "${AKS_TYPE}" ==  "default" ]; then
	 ./install-aks-10.sh ${RG} ${LOCATION} ${CORES} ${COUNT}
elif [ "${AKS_TYPE}" ==  "advnet" ]; then
	 ./install-aks-13.sh ${RG} ${LOCATION} ${CORES} ${COUNT}
elif [ "${AKS_TYPE}" ==  "aci" ]; then
	 ./install-aks-12.sh ${RG} ${LOCATION} ${CORES} ${COUNT}
else
	 echo "Unrecognized aks-type"
	 exit 7
fi

if [ "$?" -ne 0 ];then
	 update_status "Create Failed" 
	 exit 10
fi	


if [ "${CLOUDDRIVES}" == "yes" ] || [ "${CLOUDDRIVES}" == "no" ];then
  # Not yes or no; then no portworx

  log_msg "Installing Portworx; this step can take up to 10 minutes"
  ./install-portworx-15.sh ${RG} 1024 ${CLOUDDRIVES} 
  if [ "$?" -ne 0 ];then
	   update_status "Create Failed" 
	   exit 15
  fi	

  kubectl --kubeconfig=${KC} apply -f ../portworx-storageclasses.yaml
fi

log_msg "Installing Datastore"
./install-datastore-es-25.sh ${RG} ${DEV}
if [ "$?" -ne 0 ];then
	 update_status "Create Failed" 
	 exit 25
fi	

log_msg "Installing Gateway"
./install-gateway-kafka-30.sh ${RG} ${DEV}
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
