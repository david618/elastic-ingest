#!/bin/bash
set -e

helm delete --purge datastore-elasticsearch-master
helm delete --purge datastore-elasticsearch-client
helm delete --purge datastore-elasticsearch-data