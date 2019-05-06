#!/bin/bash
set -e

echo "Installing Kibana for Datastore"
#helm install --name datastore-kibana ./kibana
helm upgrade --wait --timeout=600 --install --values ./kibana/kibana-values.yaml datastore-kibana ./kibana

# instead of doing a kubectl apply, 
# we can move the below yaml file into the helm templates folder ./logstore-kibana/templates,
# which will cause it to apply with the helm install step
kubectl apply -f ./kibana/datastore-kibana-ext-lb.yaml
