
## AWS EKS Install

**4 Jun 19**

Deployed on M5.4xlarge (16 cores VM's similar to D16sv3 on Azure).

The performance on EKS about 30% faster than on AKS.

Using 6 executors the peformance on EKS was close to same as off k8s.  Some tests were as high as 180k/s for three nodes.  Longer tests showed the rate drop over time; but still fairly close to rates off k8s.


### Created EKS using eksctl


References
- https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html#eksctl-create-cluster
- https://github.com/weaveworks/eksctl

```
cat create-eks.sh
```

```
#!/bin/env bash

eksctl create cluster \
--name dj0603 \
--region us-east-2 \
--version 1.12 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 6 \
--nodes-min 6 \
--nodes-max 6 \
--node-ami auto \
--ssh-public-key centos
```

```
bash create-eks.sh
```

Took 10-15 mins
- Created EKS and 6 m5.4xlarge node in us-east-2 (Ohio)
- Using centos.pem I was able to log into one of nodes using it's Public IP (ssh -i centos.pem ec2-user@IP)



Added 1TB drive to each nodes


**NOTE:** The nodes were automatically in three different AZ's (a, b, and c)

Verified the disks showed up on VM's

sudo fdisk -l

/dev/nvme1n1: 1000GiB 

### Install Metrics Server

https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html

I noticed kubectl top pods and kubectl top nodes was not working; after install metrics server per instructions. They started working.




### Installed Dashboard 

```
https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html
```

Dashboard:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
```
Heapster:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
```
InfluxDB:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
```
Heapster Cluster Role Binding
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
```


#### Created eks-admin

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eks-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: eks-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: eks-admin
  namespace: kube-system
```

### Install Helm

```
helm  init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```

### Portworx

Looked at install docs for a few minutes; instructions for using cloud drives.  Requires IAM roles; etc.  Could do, but would require more time

### Datastore

Removed Porworx references

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values-nopx.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values-nopx.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```

### Gateway

Removed Portworx references.  Renamed values.yaml (Eventhough I specified values-nopx.yaml; it kept picking it up).

```
helm upgrade --wait --timeout=600 --install --values ../cp-helm-charts/values-nopx.yaml gateway ../cp-helm-charts
```

### SparkOperator


```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm  install incubator/sparkoperator --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

### Create Planes3 Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
```

### Start SparkJob

```
kubectl apply -f sparkop-es-2.4.1.yaml
```

### Deploy rttest-mon

```
kubectl apply -f rttest-mon.yaml
```

### EIM Mon

```
kubectl exec -it rttest-mon-2 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 6

```

### KTM Mon

```
kubectl exec -it rttest-mon-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```

### Start Send

```
kubectl apply -f rttest-send-kafka-25k-10m.yaml
```

Deployment configured to use eight instances; expected total rate is 200k/s, sending 40 million total messages.

To restart: kubectl delete pod -l app=rttest-send-kafka-25k-10m


### Results

### Two Data nodes using 14 cpu/50G mem (26GB heap) for each node

EIM Rate: 126k/s

### Longer Test Sending 200 Million Planes Messages

EIM Rate Started at 180k/s after 20 minutes rate as 128k/s.

### Five Data nodes using 14 cpu/50G mem (2GB heap) for each node

Sending at 4x25 (200k/s): EIM Rate was 198k/s
Sending at 12x25 (300k/s): EIM Rate was 249k/s

### Observations

- Rates are much close to what we got off AKS; best rate no mater number of nodes on AKS was 100k/s
- Rates also increased when additional data nodes were added

### Tear Down

```
eksctl get cluster --region us-east-2
eksctl get nodegroup --cluster dj0603 --region us-east-2
eksctl delete cluster --region us-east-2 dj0603
```







