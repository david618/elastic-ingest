### Setup EKS 25 Nodes using kubernetes 1.13

Using [eksctl](https://eksctl.io/)

Used brew to upgrade my eksctl.  The older version did not support creating 1.13.

```
eksctl create cluster \
--name dj0813 \
--region us-east-2 \
--version 1.13 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 25 \
--nodes-min 25 \
--nodes-max 25 \
--node-ami auto \
--ssh-public-key centos
```

This creates a 25 node cluster using m5.4xlarge (16 cores/64GB mem) and EKS enabled.

#### Install Dashboard

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
```

#### Set Service Account Permissions

```
kubectl apply -f eks-admin.yaml
```

#### Install Helm

```
helm  init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```


#### Add Drives

Manually Created 14 Volumes
- 1024GB each
- 5 in zone-a
- 5 in zone-b
- 4 in zone-c

Attached the disks to Instances.  Each to separate instance in the corresponding zones.


#### Install Portworx

https://install.portworx.com/

```
kubectl version --short | awk -Fv '/Server Version: / {print $3}'
1.13.8-eks-a977ba
```

- ETCD: Build-in
- Cloud: Consume Unused; Skip KVDB
- Network: auto / auto
- EKS

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.13.8-eks-a977ba&b=true&c=px-cluster-45ff9f6d-5375-4a85-8a35-81f1383a43bc&eks=true&stork=true&lh=true&st=k8s'
```

Wait for pods to start.

```
kubectl -n kube-system get pods
```

```
kubectl -n kube-system exec portworx-dbwwz -- /opt/pwx/bin/pxctl status
```

Shows 14TB Capacity.

Create Storage Classes

```
kubectl apply -f ../portworx-storageclasses.yaml
```

#### Add Taints and Labels

```
kubectl taint nodes ip-192-168-91-42.us-east-2.compute.internal key=test:NoSchedule
kubectl taint nodes ip-192-168-93-30.us-east-2.compute.internal key=test:NoSchedule
kubectl taint nodes ip-192-168-95-14.us-east-2.compute.internal key=test:NoSchedule

kubectl label nodes ip-192-168-91-42.us-east-2.compute.internal func=test
kubectl label nodes ip-192-168-93-30.us-east-2.compute.internal func=test
kubectl label nodes ip-192-168-95-14.us-east-2.compute.internal func=test
```


#### Install Elasticsearch 


Set schedulerName "stork" and storageClassName to "px-db-rf3-dbr-sc"

From aks/azcli folder of repo.

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```

```
kubectl edit sts datastore-elasticsearch-client
```

Changed replicas from 2 to 10.

#### Install Gateway 

Set schedulerName "stork" and storageClassName to "px-db-rf3-dbr-sc"

```
helm upgrade --wait --timeout=600 --install --values ../helm-charts/confluent/values-prod.yaml gateway ../helm-charts/confluent
```

#### Install Spark Operator

```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm install incubator/sparkoperator --name spark --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

#### Run Tests

From aks/manifests folder.

```
bash run-test-10part.sh > dj0813-px3-dbr-08131109.log &
```
