#!/bin/bash

set -e

if [ "$#" -lt 2 ];then
	echo "Usage: $0 [ResourceGroupName] [Dev=yes/no]"
  exit 4 
fi

# We could use a parameter based on tenant (small, standard, large)

RG=$1
DEV=$2

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
if [ ${DEV} == "yes" ]; then
  helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values-dev.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
  helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values-dev.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
else
  helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
  helm --kubeconfig=${KC} upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
fi

echo "ElasticSearch Datastore installed"