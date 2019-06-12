
## Test Azure Advanced Networking

Use Azure CNI instead of default kubenet plugin.

### Create Cluster

From install/aks/azcli.

```
azcli/install-aks-11.sh dj0612c
```

This will
- create resource group dj0612c
- create virtual network in dj0612c
- create aks in dj0612c

Here's the snippet from the script that creates the AKS.

```
az aks create \
    --resource-group ${RG} \
    --name ${CLUSTER} \
    --node-count ${COUNT} \
    --node-vm-size ${SIZE} \
    --admin-username ${USER} \
    --ssh-key-value ${PUBKEY} \
    --node-osdisk-size 100 \
    --network-plugin azure \
	--vnet-subnet-id ${SUBNETID} \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.0.0.10 \
    --service-cidr 10.0.0.0/16 \
    --kubernetes-version 1.12.7
```

Verfied that AKS networking was "Advanced/(Azure CNI)"

### Installed Elasticsearch 

- 2 Data Nodes and 3 Masters

```
./install-datastore-es-20-nopx.sh dj0612c
```


data nodes: 14 cpu and 50GB mem (26GB heap)

### Installed Kafka

- 3 zookeeper
- 3 brokers

```
./install-gateway-kafka-30.sh dj0612c
```


### Install SparkOperator


```
./install-sparkoperator-65.sh dj0612c
```


### Create Kafka Topics

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5
```

### Deploy rttest-mon

```
kubectl apply -f rttest-mon.yaml
```


### Start SparkJob

Edit  `` sparkop-es-2.4.1.yaml``

- topic planes3
- 6 instances

```
kubectl apply -f sparkop-es-2.4.1.yaml
```



### Start ElasticIndexMon (EIM)

```
kubectl exec -it rttest-mon-2 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8
```


### Start KafkaTopicMon (KTM)


```
kubectl exec -it rttest-mon-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```


### Start Send Kafka

Edited to make sure sending to planes3

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```


### Chaning Number of Elasticsearch Nodes

```
kubectl edit statefulset datastore-elasticsearch-client
```

Change the number of replicas to the number of nodes you want to test.

### Results


|Number Elasticsearch Node|Average EIM Rate|Kafka Partitions|
|-------------------------|----------------|----------------|
|2                        |89k/s           |3               |
|2                        |71k/s           |3               |
|3                        |104k/s          |3               |
|3                        |97k/s           |3               |
|5                        |98k/s           |3               |
|5                        |112k/s          |5               |

Observations
- Improved the base ingest rate.  Runs on kubenet were around 80k/s on average.
- Ingest rate does not scale linearly; 5 nodes is about 10% faster than 2 nodes. 

