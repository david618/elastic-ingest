#!/bin/usr/env bash

RG=$1

. ./support.sh ${RG}

az aks get-credentials --resource-group ${1} --name ${1}-cluster --overwrite-existing 
az aks get-credentials --resource-group ${1} --name ${1}-cluster -f ${TenantFolder}/kubeconfig


