#!/bin/bash
set -e

#helm install --name datastore-elasticsearch-master ./elasticsearch
helm upgrade --wait --timeout=600 --install --values ./elasticsearch/master-values.yaml datastore-elasticsearch-master ./elasticsearch
helm upgrade --wait --timeout=600 --install --values ./elasticsearch/client-values.yaml datastore-elasticsearch-client ./elasticsearch

# no need for data-only nodes, since the client nodes will act as both data & coordinator roles
#helm upgrade --wait --timeout=600 --install --values ./elasticsearch/data-values.yaml datastore-elasticsearch-data ./elasticsearch