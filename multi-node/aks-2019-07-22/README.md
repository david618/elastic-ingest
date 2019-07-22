
#### Setup

```
./create-tenant.sh dj0722a westus2 16 14 advnet nopx

```

- Resource Group: dj0722a
- Region: westus2
- Number of CPU per node:  16  (D16s_v3)
- Number of Nodes: 14
- Type Install: Advanced Networking
- Portworx: nopx (Don't install Portworx)

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
|200           |2                      |112            |40                |
|200           |3                      |161            |40                |
|300           |5                      |236            |60                |
|400           |7                      |259            |80                |
|600           |10                     |289            |60               |

Observations
- As we increase number of data nodes ingest rates increase
  - 110% increase in ingest going from 2 to 5 nodes (nearly linear growth from 2 to 5)
  - 20% increase in ingest going from 5 to 10 nodes (not linear growth)

### Delete

```
./delete_tenant.sh dj0722a
```

