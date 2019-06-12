
## Test Azure Advanced Networking

Use Azure CNI instead of default kubenet plugin.

### Create Cluster

Started tweaking install aks.

azcli/install-aks-11.sh

```
Manually created a vnet in resource group.
```

To Do: Add code to script to create subnet.  

```
SUBNETID=$(az network vnet subnet list --resource-group ${RG} --vnet-name ${RG} --query [].id --output tsv)
echo ${SUBNETID}

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
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values-nopx.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
```

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values-nopx.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```

data nodes: 14 cpu and 50GB mem (26GB heap)

### Installed Kafka

- 3 zookeeper
- 3 brokers

```
helm upgrade --wait --timeout=600 --install --values ../cp-helm-charts/values-prod-nopx.yaml gateway ../cp-helm-charts
```


### Install SparkOperator


```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm  install incubator/sparkoperator --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```


### Create Kafka Topics

kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5


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
kubectl apply -f rttest-send-kafka-25k-15m.yaml
```


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

