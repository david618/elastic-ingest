#!/bin/bash
export POD_NAME=$(kubectl get pods --namespace default -l "app=kibana,release=datastore-kibana" -o jsonpath="{.items[0].metadata.name}")
echo ES pod name used: $POD_NAME
echo "Visit http://127.0.0.1:5601 to use Kibana"
kubectl port-forward --namespace default $POD_NAME 5601:5601