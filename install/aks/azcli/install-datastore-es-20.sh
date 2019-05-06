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
cnt=0
ready=$(kubectl --kubeconfig=${KC} get deployment -n kube-system tiller-deploy -o json | jq .status.readyReplicas)
if [ "$ready" == null ];then ready=0; fi;
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

# Install Datastore
echo "Installing Datastore"
echo "Started Datastore Install"
helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/master-values.yaml datastore-elasticsearch-master ../datastore/elasticsearch
helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/client-values.yaml datastore-elasticsearch-client ../datastore/elasticsearch
