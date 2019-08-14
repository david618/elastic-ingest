#!/bin/bash

PXPOD=$(kubectl -n kube-system get pods -l name=portworx -o name | head -n 1)

PVCS=$(kubectl get pvc -l app=datastore-elasticsearch-client -o=custom-columns=:.spec.volumeName)
for PVC in ${PVCS}; do
  kubectl -n kube-system exec -it ${PXPOD} -- /opt/pwx/bin/pxctl v i $PVC | grep "Bytes used"
done
