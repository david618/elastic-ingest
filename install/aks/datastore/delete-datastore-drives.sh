#!/bin/bash
set -e

kubectl get pvc -o name | grep datastore | xargs kubectl delete