

###  Setup

./create-tenant-aci.sh dj0711a latest westus2 16 6 disabled yes

- Ressource Group: dj0711a
- A4IOT Build: latest
- Region(location): westus2
- CpuPerNode: 16  (D16sv3)
- NumberNodes: 6
- StorageAccount: disabled
- CloudDrives: yes  (Let Portworx Create Data Drives it needs)

The "aci" install includes

```
    --network-plugin azure \
```

It also enables the "virtual-node" addon; however, ACI was not used in this test.


The datastore (Elasticsearch) configuration
- Two data nodes
- Resources for each node:  14 cpu, 50Gi memory; ES_JAVA_OPS: -Xmx26g -Xms26g 

####  Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
```

####  Start SparkJob


```
kubectl apply -f sparkop-es-2.4.1.yaml
```


#### Deploy rttest-mon

```
kubectl apply -f rttest-mon.yaml
```


#### Elastic Index Monitor (EIM)

```
kubectl exec -it rttest-mon-2 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8
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

Deployment configured to use eight instances; expected total rate is 200k/s, sending 40 million total messages.

To restart: kubectl delete pod -l app=rttest-send-kafka-25k-5

#### Increased Number of Elasticsearch Data Nodes

##### Added AKS Nodes

Scaled AKS with additional nodes.  (e.g. added three new nodes for 5 test)

##### Edit Statefulset 

```
kubectl edit statefulset datastore-elasticsearch-client
```

Change number of replicas (e.g. 2 to 5)

Wait for pods to start.


##### Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5
```

##### Delete and restart SparkJob

```
kubectl delete -f sparkop-es-2.4.1.yaml
kubectl apply -f sparkop-es-2.4.1-5part.yaml
```

##### Stop and restart monitors

```
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8

java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes5
```

##### Stop and Start Send

After sparkop is running.

```
kubectl delete -f rttest-send-kafka-25k-5m.yaml
kubectl apply -f rttest-send-kafka-25k-5m-5part.yaml
```

#### Results

Portworx Installed Replication Factor 3

|Number Data Nodes|EIM Rate    |
|-----------------|------------|
|2                |90  k/s     |   
|5                |102 k/s     |
|7                |133 k/s     |
|10               |170 k/s     |


#### Reset for Portworx Replication 1

##### Stop Tests
```
kubectl delete -f sparkop-es-2.4.1-10part.yaml
kubectl delete -f rttest-send-kafka-25k-5m-10part.yaml
```

##### Remove Datastore and Volumes
```
helm delete --purge datastore-elasticsearch-client
helm delete --purge datastore-elasticsearch-master
kubectl delete pvc -l app=datastore-elasticsearch-client
kubectl delete pvc -l app=datastore-elasticsearch-master
```

##### Edit

Created modified helm values using Portworx volume with replication factor of 1.



|Number Data Nodes|EIM Rate    |
|-----------------|------------|
|10               |261 k/s     |


##### Reset for No Portworx

Same as previous section; stop, remove, and edit.

Using Azure ``managed-premium`` storage class. 


|Number Data Nodes|EIM Rate    |
|-----------------|------------|
|10               |332 k/s     |


#### Observations

- Ingest with Portworx Replication Factor of 1 is 50% faster than Portworx with Replication Factor of 3 
- Ingest with Azure Preimium is 30% faster than Portworx (rf1) and 95% faster than Portworx (rf3)
