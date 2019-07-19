

### Various Configuration of Storage Classes

Ingest rates for 2 and 3 data nodes with various combinations of Storage Classes
- Portworx Replication Factor 3 (rf-3)
- Portworx Replication Factor 2 (rf-2)
- Portworx Replication Factor 1 (rf-1)
- Portwork Replication Factor 1 without security 
- Azure Managed Premium

#### Tweaked install-aks-12.sh
- Commented out section "Enable Virtual Nodes" section.

```
#echo "Enable Virtual Node"
#
#az aks enable-addons \
#    --resource-group ${RG} \
#    --name ${CLUSTER} \
#    --addons virtual-node \
#    --subnet-name ${NODE_SUBNET_NAME}
```

#### Ran the installer

```
./create-tenant-aci.sh dj0718c latest westus2 16 6 disabled yes
```


- ResourceGroup: dj0718c
- A4IOT Build: latest
- Region: westus2
- CoresPerNode: 16 =>  D16s_v3
- NumberOfNodes: 6
- StorageAccount: disabled
- CloudDrives: yes  

Default install of Datastore has (2 Elasticsearch data nodes).

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

Change number of replicas (e.g. 2 to 3)

Wait for pods to start.

#### Reset for Different Datastore Configuration

For example to change storage type. 

##### Stop Tests
```
kubectl delete -f sparkop-es-2.4.1-10part.yaml
kubectl delete -f rttest-send-kafka-25k-5m-10part.yaml
```

##### Remove Elasticsearch (Datastore) and Volumes

```
helm delete --purge datastore-elasticsearch-client
helm delete --purge datastore-elasticsearch-master
kubectl delete pvc -l app=datastore-elasticsearch-client
kubectl delete pvc -l app=datastore-elasticsearch-master
```
##### Remove Kafka (Gateway) and Volumes

```
helm delete --purge gateway
kubectl delete pvc -l app=cp-kafka
kubectl delete pvc -l app=cp-zookeeper
```


#### Results

##### Kafka Portworx (rf=3), Elasticsearch Portworx (rf=3)


|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |107 k/s     |40m     |
|2       |2                |89 k/s      |40m     |
|3       |2                |94 k/s      |40m     |
|4       |3                |92 k/s      |40m     |



Observations
- During test run 4; two error messages in Kafka Topic Mon "commit failed on partition planes3-0"


##### Kafka Portworx (rf=3), Elasticsearch Portworx (rf=2)


|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |93 k/s      |40m     |
|2       |2                |92 k/s      |40m     |
|3       |3                |100 k/s     |40m     |


##### Kafka Portworx (rf=3), Elasticsearch Portworx (rf=1)


|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |97 k/s      |40m     |
|2       |2                |92 k/s      |40m     |
|3       |3                |117 k/s     |40m     |


##### Kafka Portworx (rf=3), Elasticsearch Portworx (rf=1, not encrypted)


|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |93 k/s      |40m     |


##### Kafka Portworx (rf=3), Elasticsearch Azure Managed Premium

|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |112 k/s     |40m     |
|2       |3                |137 k/s     |40m     |


##### Kafka Azure Managed Premium and Elasticsearch Portworx (rf=1)

|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |116 k/s     |40m     |
|2       |3                |137 k/s     |40m     |

##### Kafka and Elasticsearch managed Premium 

|Test Run|Number Data Nodes|EIM Rate    |Num Sent|
|--------|-----------------|------------|--------|
|1       |2                |122 k/s     |40m     |
|2       |3                |128 k/s     |40m     |


#### Observations

- While not reported in tables able the Kafka Topic Monitor closely matched send rate 200k/s
- Using Azure Manage Premium disks for some or all volumes provides better ingest (10 to 17% better)


