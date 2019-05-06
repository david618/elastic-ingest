#!/bin/bash
export POD_NAME=$(kubectl get pods --namespace default -l "app=datastore-elasticsearch-client" -o jsonpath="{.items[0].metadata.name}")
echo ES pod name used: $POD_NAME
echo "Visit http://127.0.0.1:9200 to use Elasticsearch"
kubectl port-forward --namespace default $POD_NAME 9200:9200