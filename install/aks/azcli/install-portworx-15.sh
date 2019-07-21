#!/bin/bash

set -e

if [ "$#" -lt 1 ];then
  echo "Usage: $0 [ResourceGroupName] (sizeGB=1024) (cloudDrives=no)"
  echo "Example: $0 dj0218"
  echo "Add a 1024GB disk to each AKS node and install Portworx"
	echo "Example: $0 dj0218 2048 yes"
	echo "Create 2048GB disk for each node and install Portworx"
  exit 4
fi

az vm list -o table > /dev/null 2>&1
if [ $? -ne 0 ];then
  echo 'You need to login first. Run "az login"'
  exit 5
fi

RG=$1
SIZEGB=1024
if [ "$#" -ge 2 ];then
  SIZEGB=$2
fi

USECLOUDDRIVES=no
if [ "$#" -ge 3 ];then
  USECLOUDDRIVES=$3
fi

. ./support.sh ${RG}

MCRG=$(az aks list --subscription ${SID} --resource-group ${RG} | jq --raw-output '.[0].nodeResourceGroup')

NUMNODES=0
# Add a disk to each aks node if USECLOUDDRIVES == no; get the NUMNODES either way
for node in $(az vm list --subscription ${SID} -g ${MCRG} | jq --raw-output .[].name | grep aks); do
	if [ "${USECLOUDDRIVES}" == "no" ];then			
    az vm disk attach --subscription ${SID} -g ${MCRG} --vm-name ${node} --name ${node}d1 --new --size-gb ${SIZEGB}
    echo "Disk ${node}d1 added."
	fi	
  NUMNODES=$((${NUMNODES}+1))
done

kubectl --kubeconfig=${KC} create ns portworx

# Create Random Key
KEY=$(LC_CTYPE=C tr -dc A-Za-z0-9 < /dev/urandom | fold -w 128 | cut -c 1-64 | head -n 1)

# To Do: Store KEY as Secret on Admin Server
echo ${KEY} > ${TenantFolder}/key

# Create Secret on Tenant Cluster; for now use a literal key "mysecret"
kubectl --kubeconfig=${KC} -n portworx create secret generic px-vol-encryption --from-literal=cluster-wide-secret-key=${KEY}

FILE=${TenantFolder}/install-portworx.yaml

UUID=$(uuidgen | tr A-Z a-z)

if [ "${USECLOUDDRIVES}" == "no" ];then
  echo "Using Attached Drives"
  curl -o ${FILE} "https://install.portworx.com/2.1?mc=false&kbver=$(kubectl --kubeconfig=${KC} version --short | awk -Fv '/Server Version: /{print $3}')&b=true&c=${RG}-${UUID}&aks=true&stork=true&lh=true&st=k8s&cluster_secret_key=cluster-wide-secret-key"
else
  echo "Using Cloud Drives"
       curl -o ${FILE} "https://install.portworx.com/2.1.2-rc2?mc=false&kbver=$(kubectl --kubeconfig=${KC} version --short | awk -Fv '/Server Version: /{print $3}')&b=true&c=${RG}-${UUID}&aks=true&stork=true&lh=true&st=k8s&cluster_secret_key=cluster-wide-secret-key&s=%22type%3DPremium_LRS%2Csize%3D${SIZEGB}%22"
fi

kubectl --kubeconfig=${KC} apply -f ${FILE}

# Create Service Principal (Required for Portworx 2.1 starting on 18 Jun 2019

RBAC=$(az ad sp create-for-rbac --role="Contributor" -n http://${RG} --subscription ${SID})
APPID=$(echo $RBAC | jq .appId --raw-output)
APPPW=$(echo $RBAC | jq .password --raw-output)
TENID=$(echo $RBAC | jq .tenant --raw-output)

kubectl --kubeconfig=${KC} create secret generic -n kube-system px-azure \
  --from-literal=AZURE_TENANT_ID=${TENID} \
  --from-literal=AZURE_CLIENT_ID=${APPID} \
  --from-literal=AZURE_CLIENT_SECRET=${APPPW}


echo "Waiting for Portworx to Start; this can take another 15  minutes"
cnt=0
ready=0
while [ "$ready" -lt "${NUMNODES}" ];do
  ((cnt+=1))
  sleep 60
  ready=$(kubectl --kubeconfig=${KC} get pods -n kube-system -l name=portworx -o custom-columns=ready:.status.containerStatuses[0].ready | grep true | wc -l)
  if [ "$ready" == null ];then ready=0; fi;
  echo $ready
  if [ "$cnt" -gt 15 ];then
    # After 15 minutes give up
    log_msg "Portworx is taking too long to start. Aborting install"
    exit 1
  fi
done

# Set Encryption Key
PX_POD=$(kubectl --kubeconfig=${KC} get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl --kubeconfig=${KC} exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets set-cluster-key --secret cluster-wide-secret-key

echo "Portworx Installed"
