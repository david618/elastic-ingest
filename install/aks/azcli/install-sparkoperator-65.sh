#!/bin/bash

#set -e

if [ "$#" -lt 1 ];then
  echo "Usage: $0 [ResourceGroupName]"
  exit 4 
fi

RG=$1
. ./support.sh ${RG}

# Wait for tiller
cnt=0
ready=$(kubectl get deployment -n kube-system tiller-deploy -o json | jq .status.readyReplicas)
if [ "$ready" == null ];then ready=0; fi;
while [ "$ready" -lt 1 ];do
  ((cnt+=1))
  sleep 30 
  ready=$(kubectl get deployment -n kube-system tiller-deploy -o json | jq .status.readyReplicas)
  if [ "$ready" == null ];then ready=0; fi; 
  echo $ready
  if [ "$cnt" -gt 6 ];then
    echo "Tiller is taking too long to start. Aborting install"
    exit 1
  fi
done
  

# Install Spark Operator
echo "Installing Spark Operator"

helm --kubeconfig=${KC} repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm --kubeconfig=${KC} install incubator/sparkoperator --namespace spark-operator --set enableWebhook=true

# Apply RBAC for Spark Operator
kubectl --kubeconfig=${KC} create serviceaccount spark
kubectl --kubeconfig=${KC} create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default


echo "Install Spark Operator started"

