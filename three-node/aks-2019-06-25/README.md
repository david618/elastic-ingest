### Setup

Installed A4IOT with 9 nodes

Datastore data nodes configured with 14 cpu; 50GB mem, and heap configured at 26GB.

Compare Portworx to Azure Drives

#### Azure Drives 

```
./create-test-tenant-nopx.sh dj0624c westus2 16 6
```

#### Portworx

```
./create-test-tenant.sh dj0624c westus2 16 6
```

In this test Portworx was configured to use 1TB drives attached to the AKS nodes.  

### Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5
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
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8
```

### KTM Mon

```
kubectl exec -it rttest-mon-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```

### Start Send

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```

Deployment configured to use eight instances; expected total rate is 200k/s, sending 40 million total messages.

To restart: ``kubectl delete pod -l app=rttest-send-kafka-25k-5m``


### Results


Datastore (Elasticsearch) Nodes: 
- 14 cpu
- 50GB mem
- JavaOps Xmx/Xms: 26GB

For 3 and five node tests Scaled Kubernetes to 9 nodes.

#### Azure Drives (nopx)

|Num ES Nodes|EIM Rate|
|------------|--------|
|2           |81k/s   |
|3           |94k/s   |
|5           |108k/s  |


#### Portworx 

|Num ES Nodes|EIM Rate|
|------------|--------|
|2           |58k/s   |
|3           |93k/s   |
|5           |67k/s   |


#### Observations

- Azure Drives in this test were faster (For 5 node test Azure was 60% faster than Porworx Drives)
- Results don't scale linearly for either test
  - If 2 nodes give 81k/s; for linearly growth 3 nodes should give 120k/2 and 5 nodes should be close to 200k/s
  - On EKS and Off Kubernetes we saw near linear growth


