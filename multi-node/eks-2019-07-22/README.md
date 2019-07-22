
### Setup 

Using [eksctl](https://eksctl.io/)



```
eksctl create cluster \
--name dj0722c \
--region us-east-2 \
--version 1.12 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 14 \
--nodes-min 14 \
--nodes-max 14 \
--node-ami auto \
--ssh-public-key centos
```

This creates a 14 node cluster using m5.4xlarge (16 cores/64GB mem) and EKS enabled.

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


#### Install Metrics (optional)

Follow [Installing the Kubernetes Metrics Server](https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html)


#### Install Elasticsearch 

From install/aks/azcli folder.

Edit values files: 

```
vi ../stores/datastore/es-client-values.yaml
vi ../stores/datastore/es-master-values.yaml
```

Change sroageClassName

```
storageClassName: "gp2"
```

**NOTE:** gp2 is the default Storage Class for AWS.  This is for general purpose ssd. 

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```

### Install Gateway 

From install/aks/azcli folder.

Edit value file:

```
vi ../helm-charts/confluent/values-prod.yaml
```

Set Storage Class Lines

```
dataDirStorageClass: "gp2"
dataLogDirStorageClass: "gp2"
storageClass: "gp2"
```

```
helm upgrade --wait --timeout=600 --install --values ../helm-charts/confluent/values-prod.yaml gateway ../helm-charts/confluent
```

### Install Spark Operator

```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm  install incubator/sparkoperator --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```



####  Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes7 --create --replication-factor 1 --partitions 7
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes10 --create --replication-factor 1 --partitions 10

```

####  Start SparkJob


```
kubectl apply -f sparkop-es-2.4.1.yaml
```


#### Deploy rttest-mon

```
kubectl apply -f rttest-mon.yaml
```

**NOTE: ** Wait for rttest and sparkop job to deploy.


#### Elastic Index Monitor (EIM)

```
kubectl exec -it rttest-mon-2 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 70
```

#### Kafka Topic Monitor (KTM)

```
kubectl exec -it rttest-mon-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```

#### Start Send

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```


### Results

|Sending at k/s|Number of ES Data Nodes|EIM Rate (k/s) |Num Sent (million)|
|--------------|-----------------------|---------------|------------------|
|200           |2                      |159            |40                |
|200           |3                      |180            |40                |
|300           |5                      |265            |60                |
|400           |7                      |415            |160               |
|600           |10                     |466            |240               |

Observations
- As we increase number of data nodes ingest rates increase
  - 67% increase in ingest going from 2 to 5 nodes
  - 70% increase in ingest going from 5 to 10 nodes 
- During this test we were limited to 14 nodes
  - When we have 10 Elasticsearch data nodes; that leave only 4 nodes
  - The 4 remaining nodes are run Spark, Kafka, and Test Sending Messages 00
  - If we truely double the number of servers; we may get closer linear growth


### Delete

```
eksctl get cluster -r us-east-2
NAME    REGION
dj0722c us-east-2
```

```
eksctl delete cluster dj0722c -r us-east-2
```
