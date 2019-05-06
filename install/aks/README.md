
## Setup Test Cluster


### Create Cluster 

Run this command

```
./create-test-tenant.sh dj0419 westus2 32 9
```

or 

Run components one py one.


```
./install-aks-10.sh dj0419 westus2 32 9
./install-portworx-15.sh dj0419
./install-datastore-es-20.sh dj0419
./install-gateway-kafka-30.sh dj0419
./install-sparkoperator-65.sh dj0419
```

This starts with 9 32-core nodes; we can increase the size when needed for additional tests.

### Add Test Nodes

Add three additional nodes.  From Azure Portal naviate to the AKS and scale increasing from 9 to 12.

These additional nodes will not have Portworx drives.

**Note:** When we scale to 60 nodes; we won't want to have 60 Portworx drive.   

### Assign Labels

kubectl get nodes

Identify the node names.

```
kubectl label node  aks-nodepool1-32638272-9  func=test
kubectl label node  aks-nodepool1-32638272-10  func=test
kubectl label node  aks-nodepool1-32638272-11  func=test
```

### Deploy rttest mon and send

The yaml files are in the tools folder.

```
kubectl apply -f rttest-mon.yaml
kubectl apply -f rttest-send.yaml
```




