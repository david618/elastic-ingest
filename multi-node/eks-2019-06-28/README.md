
## EKS up to 10 Data Nodes

Portworx and Gp2 (AWS) Volumes


### Create EKS Cluster

```
#!/bin/env bash

eksctl create cluster \
--name dj0628aws \
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

bash create-eks.sh

### Add Data Disk to Instances 

Added 1TB volume to six of the 14 nodes; two in each AZ.


#### Install Helm


helm  init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'


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

For Gp2 (No Portworx)

```
helm  upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/master-values-gp2.yaml datastore-elasticsearch-master ../datastore/elasticsearch

helm  upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/client-values-gp2.yaml datastore-elasticsearch-client ../datastore/elasticsearch




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
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes7 --create --replication-factor 1 --partitions 7
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes10 --create --replication-factor 1 --partitions 10

```
### Start SparkJob

```
kubectl apply -f sparkop-es-2.4.1-5part.yaml
```

Used slight variations for other patition settings.

```
kubectl apply -f sparkop-es-2.4.1-7part.yaml
kubectl apply -f sparkop-es-2.4.1-10part.yaml
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

or

```
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes5
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes10
```

### Start Send

```
kubectl apply -f rttest-send-kafka-25k-5m-5part.yaml
```

```
kubectl apply -f rttest-send-kafka-25k-5m-7part.yaml
kubectl apply -f rttest-send-kafka-25k-5m-10part.yaml
```

### Changing Number of Datanode Clients

```
kubectl edit statefulset datastore-elasticsearch-client
```

Change number of replicas: 5, 7, 10


### Results

Each Data node: 14 cpu and 50GB mem

ES_JAVA_OPS = -Xmx26g -Xms26g



|Number Data Nodes|Kafka Partitions|EIM Ingest Rate PX|EIM Ingest Rate GP2|
|-----------------|----------------|------------------|-------------------|
|2                |5               |160k/s            |180k/s             |
|5                |5               |178k/s            |268k/s             |
|7                |7               |157k/s            |374k/s             |
|10               |10              |204k/s            |506k/s             |



### Observations

- For 10 node test; could not scale Spark workers without adding more nodes; adding more nodes might have given higher performance
- Ingest rate with Portworx is not scaling as it does for gp2
  - Both showed higher per node rate at 2 (Portworx 80k/s and GP2 90k/s)
  - GP2 (5, 7, and 10) per nodes rate was about 50k/s (Linear Growth)
  - Portworx (5, 7, 10) per node rate dropped from 35k/s to 20k/s.




