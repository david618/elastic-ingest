### Setup

Installed A4IOT with 6 nodes.

Datastore configured with 14 cpu; 50GB mem, and heap configured at 26GB.

Tested using Kubernetes 1.12.8 instead of 1.12.7 (previous tests)

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


Datastore: 
- 14 cpu
- 50GB mem
- JavaOps Xmx/Xms: 26GB


|Num ES Nodes|EIM Rate|
|------------|--------|
|2           |55k/s   |
|3           |65k/s   |
|5           |56k/s   |

