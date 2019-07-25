### Change from Kubernetes 1.12.8 to 1.13.7


#### Setup

```
/create-tenant.sh dj0724b eastus2 16 14 aci no
```

Modifed install script to install 1.13.7.

```
    --kubernetes-version 1.13.7 \
```


#### Scaled Elasticsearch to 7 Nodes


```
kubectl edit statefulset datastore-elasticsearch-client
```

Changed replicas from 2 to 7.  Waited for data nodes to all start.


#### Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes7 --create --replication-factor 1 --partitions 7
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes10 --create --replication-factor 1 --partitions 10
```

#### Deploy Spark Job

```
kubectl apply -f sparkop-es-2.4.1-7part.yaml
```

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

#### Send and Collected Results for 7 nodes

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```

#### Repeated the tests for 10 nodes.

```
kubectl edit statefulset datastore-elasticsearch-client
```
Changed from 7 to to 10 nodes

```
kubectl apply -f sparkop-es-2.4.1-10part.yaml
kubectl apply -f rttest-send-kafka-25k-5m-10part.yaml
```


#### Results

|Test Run Number|Num Elasticsearch Nodes|Ingest Rate (k/s)      |Number of Messages Sent (million)|
|---------------|-----------------------|-----------------------|---------------------------------|
|1              |7                      |246                    |80                               |
|2              |7                      |278                    |80                               |
|3              |7                      |216                    |80                               |
|4              |10                     |309                    |100                              |
|5              |10                     |264                    |100                              |
|6              |10                     |274                    |100                              |


Average Ingest
- 7 nodes: 246
- 10 nodes: 282

### Increase Number of Nodes to 24

Scaled AKS from 14 to 24.  Repeated tests

|Test Run Number|Num Elasticsearch Nodes|Ingest Rate (k/s)      |Number of Messages Sent (million)|
|---------------|-----------------------|-----------------------|---------------------------------|
|1              |7                      |390                    |80                               |
|2              |7                      |357                    |160                               |
|3              |7                      |280                    |160                              |
|4              |10                     |293                    |200                              |
|5              |10                     |298                    |200                              |
|6              |10                     |294                    |200                              |

Observations
- For 10 nodes the rate dropped unexpected
  - In one test the the rate started high (over 500k/s) then dropped and leveled out at 300
  - Looked at metrics was not able to find any good explanation for drop 

  

