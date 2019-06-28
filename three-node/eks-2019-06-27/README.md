
## EKS With Portworx Drives


### Create EKS Cluster

```
#!/bin/env bash

eksctl create cluster \
--name dj0627aws \
--region us-east-2 \
--version 1.12 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 9 \
--nodes-min 9 \
--nodes-max 9 \
--node-ami auto \
--ssh-public-key centos
```

bash create-eks.sh

### Add Data Disk to Instances 

Added 1TB volume to six of the 9 nodes; two in each AZ.


### Set Encryption Key

```
kubectl create ns portworx

kubectl -n portworx create secret generic px-vol-encryption --from-literal=cluster-wide-secret-key=somereallyhardpassword1234
```

### Install Portworx


https://install.portworx.com/

Use exsiting disk space.

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.12.6-eks-d69f1b&b=true&c=px-cluster-55a574cd-6b35-453d-9ff1-619e767c7dee&stork=true&lh=true&st=k8s&eks=true'
```

```
kubectl -n kube-system exec -it portworx-5pb8c bash
```

Verified that 6TB of Portworx capacity.

```
/opt/pwx/bin/pxctl status
```

### Uninstall Portworx

If ever needed.

```
curl -fsL https://install.portworx.com/px-wipe | bash
```



### Set Key

Wait until you have verified Portworx is up and running.

```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl secrets set-cluster-key --secret cluster-wide-secret-key
```

### Define Stroage Classes

```
kubectl apply -f portworx-storageclasses.yaml
```

### Install Datastore (Elasticsearch)

```
helm upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/master-values.yaml datastore-elasticsearch-master ../datastore/elasticsearch

helm upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/client-values.yaml datastore-elasticsearch-client ../datastore/elasticsearch
```


### Install Gateway (Kafka)

```
helm upgrade --wait --timeout=600 --install --values ../cp-helm-charts/values-px.yaml gateway ../cp-helm-charts
```

### Install SparkOperator

```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm  install incubator/sparkoperator --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

### Create Kafka Topics

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
```

```
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

###  EIM Mon

```
kubectl exec -it rttest-mon-2 tmux
```

```
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8
```

### KTM Mon

```
kubectl exec -it rttest-mon-1 tmux
```

```
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```

### Start Send

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```

### Changing Number of Datanode Clients

```
kubectl edit statefulset datastore-elasticsearch-client
```

Change number of replicas.


### Results


#### 8cpu,16GB mem with Portworx

|Number Data Nodes|Kafka Partitions|EIM Ingest Rate|
|-----------------|----------------|---------------|
|2                |3               |116            |
|2                |3               |124            |
|3                |3               |134            |
|3                |3               |126            |
|5                |3               |139            |
|5                |3               |128            |
|5                |5               |164            |


#### 14cpu,50GB mem with Portworx

|Number Data Nodes|Kafka Partitions|EIM Ingest Rate|
|-----------------|----------------|---------------|
|2                |3               |132            |
|5                |3               |144            |
|5                |5               |174            |


#### 14cpu,50GB mem no Portworx (using AWS gp2 volumes)


|Number Data Nodes|Kafka Partitions|EIM Ingest Rate|
|-----------------|----------------|---------------|
|2                |3               |142            |
|5                |3               |186            |
|5                |5               |231            |

#### Observations

- Portworx does appear to be slower 
- Rates on gp2 increased more as we increased number of nodes
  - 32% gain going from 2 to 5 data nodes (Portworx)
  - 62% gain going from 2 to 5 data nodes (gp2)
  
  
**Note:** Portworx replication of 3 may be impacting the max ingest rate for Portworx. 

