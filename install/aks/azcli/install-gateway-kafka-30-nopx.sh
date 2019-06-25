#!/bin/bash

set -e

if [ "$#" -lt 1 ];then
  echo "Usage: $0 [ResourceGroupName]"
  exit 4 
fi

# We could use a parameter based on tenant (small, standard, large)

RG=$1

. ./support.sh ${RG}

# Wait for tiller
ready=$(kubectl --kubeconfig=${KC} get deployment -n kube-system tiller-deploy -o json | jq .status.readyReplicas)
if [ "$ready" == null ];then ready=0; fi; 
cnt=0
while [ "$ready" -lt 1 ];do
  ((cnt+=1))
  sleep 30 
  ready=$(kubectl --kubeconfig=${KC} get deployment -n kube-system tiller-deploy -o json | jq .status.readyReplicas)
  if [ "$ready" == null ];then ready=0; fi; 
  echo $ready
  if [ "$cnt" -gt 6 ];then
    echo "Tiller is taking too long to start. Aborting install"
    exit 1
  fi
done

# Install Gateway
echo "Installing Gateway"
#helm --kubeconfig=${KC} install --name gateway ../cp-helm-charts
helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../cp-helm-charts/values-nopx.yaml gateway ../cp-helm-charts

echo "Started Gateway Install"

