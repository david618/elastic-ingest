
### Setup EKS 24 Nodes using kubernetes 1.13

Using [eksctl](https://eksctl.io/)

Used brew to upgrade my eksctl.  The older version did not support creating 1.13.

```
eksctl create cluster \
--name dj0724 \
--region us-east-2 \
--version 1.13 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 24 \
--nodes-min 24 \
--nodes-max 24 \
--node-ami auto \
--ssh-public-key centos
```

This creates a 24 node cluster using m5.4xlarge (16 cores/64GB mem) and EKS enabled.

#### As previous test

- Install Dashboard
- Set Service Account Permissions
- Install Helm
- Install Elasticsearch 
- Install Gateway 
- Install Spark Operator
```


#### Scaled Datastore to 7 Replicas
```
kubectl edit statefulset datastore-elasticsearch-client
```
Changed from 7 to to 10 nodes

####  Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes7 --create --replication-factor 1 --partitions 7
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes10 --create --replication-factor 1 --partitions 10
```

####  Start SparkJob

```
kubectl apply -f sparkop-es-2.4.1-7part.yaml
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
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes7
```

#### Start Send

```
kubectl apply -f rttest-send-kafka-25k-5m-7part.yaml
```

### Repeated Test for 10 nodes

- Scaled Datastore from 7 to 10
- Repeated ingest tests

### Results

|Test Run Number|Number of ES Data Nodes|EIM Rate (k/s) |Num Sent (million)|
|---------------|-----------------------|---------------|------------------|
|1              |7                      |360            |160               |
|2              |7                      |302            |160               |
|3              |7                      |317            |160               |
|4              |7                      |430            |160               |
|5              |7                      |350            |160               |
|6              |7                      |383            |160               |
|7              |10                     |469            |280               |
|8              |10                     |467            |280               |
|9              |10                     |485            |280               |

- Average Rates over test runs
  - 7 Elasticsearch Nodes: 359
  - 10 Elasticsearch Nodes: 473 




