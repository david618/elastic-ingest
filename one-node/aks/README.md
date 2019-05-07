#### Created AKS

Create 4 node aks using D16sv3 nodes using the [install_aks.sh](../../install/aks/azcli/install-aks-10.sh)

```
bash install-aks-10.sh dj0507 westus2 16 4
```

#### Installed Portworx

Created a 1TB drive on each of the four nodes.


#### Install Datastore

Create single-node.yaml.  This provisions a single Elasticsearch node using 14 cpu and 56Gi mem.  This will take up an entire node.

Tried 15 cpu and 60Gi of mem; however, datastore would not deploy.  Error messages insufficent cpu and insufficent mem.  

```
helm upgrade --wait --timeout=600 --install --values ../datastore/elasticsearch/single-node.yaml datastore-elasticsearch-client ../datastore/elasticsearch
```

Created 1Ti data drive.

#### Install Kafka

Create single-node.yaml.  1 master and 1 broker.  Set broker to 14 cpu and 56Gi mem. 

Set enabled to false: cp-kafka-connnect

The default helm chart for cp-kafka set offsets.topic.replication.factor to three; will not work.  Added this to yaml.

```
  configurationOverrides:
    "offsets.topic.replication.factor": "1"
```


```
helm install --name gateway --values ../cp-helm-charts/single-node.yaml ../cp-helm-charts
```

Made a change to the single-node.yaml and upgraded using.

```
helm upgrade --values ../cp-helm-charts/single-node.yaml gateway ../cp-helm-charts
```

Eventhough I set the limit and request to same number the pod still deploys with QoS of burstable.  


#### Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
```


#### Create RBAC

The name fabric8 has no signtificance.   


kubectl apply -f fabric8-rbac.yaml


#### Deploy Sparktest

kubectl apply -f sparktest.yaml


#### Assigned Label

Checked pods and identified which node was not being used then assigned label to that node to mark it as a test node.

```
kubectl get pods -o wide
```

Then

```
kubectl label node  aks-nodepool1-33881288-3  func=test
```

#### Deploy rttest

```
kubectl apply -f rttest-mon.yaml
kubectl apply -f rttest-send.yaml
```


#### Run Spark Job

Exec into sparktest pod.


```
kubectl exec -it sparktest-bccc588d9-dhcj6 tmux
```

Run Spark Job


```
/opt/spark/bin/spark-submit \
  --conf spark.streaming.kafka.consumer.cache.enabled=false \
  --class org.jennings.estest.SendKafkaTopicElasticsearch /opt/spark/work-dir/sparktest-full.jar \
  local[8] 1000 gateway-cp-kafka:9092 group1 planes3 1 \
  datastore-elasticsearch-client 9200 - - 3 true false true planes 60s 10000 0 false
```


```
/opt/spark/bin/spark-submit \
--master k8s://https://kubernetes:443 \
--deploy-mode cluster \
--conf spark.executor.instances=9 \
--conf spark.executor.memory=5000m \
--conf spark.es.batch.size.bytes=421000000 \
--conf spark.es.batch.size.entries=50000 \
--conf spark.es.batch.write.refresh=false \
--conf spark.es.nodes.discovery=false \
--conf spark.es.nodes.data.only=false \
--conf spark.es.nodes.wan.only=true \
--conf spark.streaming.concurrentJobs=64 \
--conf spark.scheduler.mode=FAIR \
--conf spark.locality.wait=0s \
--conf spark.streaming.kafka.consumer.cache.enabled=false \
--conf spark.kubernetes.container.image=david62243/sparktest:v0.4-2.3.2 \
--conf spark.kubernetes.container.forcePullImage=true \
--conf spark.kubernetes.driver.label.appname=sparktest-es \
--conf spark.kubernetes.executor.label.appname=sparktest-es \
--class org.jennings.estest.SendKafkaTopicElasticsearch local:///opt/spark/work-dir/sparktest-full.jar \
k8s://https://kubernetes:443 1000 gateway-cp-kafka:9092 group1 planes3 1 \
datastore-elasticsearch-client-headless 9200 - - 3 true false true planes 60s 10000 0 false
```


The "driver" and "exec" should start.  You can verify using kubectl get pods.

#### Start ElasticIndexMon (EIM)

```
kubectl exec -it rttest-mon-0 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client-headless:9200/planes 10 12
```


#### Start KafkaTopicMon (KTM)

```
kubectl exec -it rttest-mon-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3

```

#### Send Kafka

```
kubectl exec -it rttest-send-0 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.send.Kafka gateway-cp-kafka-headless:9092 planes3 planes00000 100000 50000000
```


#### Results with extra params

```
--conf spark.es.nodes.discovery=false \
--conf spark.es.nodes.data.only=false \
--conf spark.es.nodes.wan.only=true \
```

- Send: 1x100k/s
- KTM: 100k/s
- EIM: 75k/s at 1 min; 51k/s at 15 min


#### Results without extra params

```
/opt/spark/bin/spark-submit \
--master k8s://https://kubernetes:443 \
--deploy-mode cluster \
--conf spark.executor.instances=9 \
--conf spark.executor.memory=5000m \
--conf spark.es.batch.size.bytes=421000000 \
--conf spark.es.batch.size.entries=50000 \
--conf spark.es.batch.write.refresh=false \
--conf spark.streaming.concurrentJobs=64 \
--conf spark.scheduler.mode=FAIR \
--conf spark.locality.wait=0s \
--conf spark.streaming.kafka.consumer.cache.enabled=false \
--conf spark.kubernetes.container.image=david62243/sparktest:v0.4-2.3.2 \
--conf spark.kubernetes.container.forcePullImage=true \
--conf spark.kubernetes.driver.label.appname=sparktest-es \
--conf spark.kubernetes.executor.label.appname=sparktest-es \
--class org.jennings.estest.SendKafkaTopicElasticsearch local:///opt/spark/work-dir/sparktest-full.jar \
k8s://https://kubernetes:443 1000 gateway-cp-kafka:9092 group1 planes3 1 \
datastore-elasticsearch-client-headless 9200 - - 3 true false true planes 60s 10000 0 false
```

- Send: 1x100k/s
- KTM: 100k/s
- EIM: 
  - 67k/s at 1 min; 51k/s at 15 min
  - Average: 55k/s
  - Linear Regression: 55; standard error: 0.87

Observation: Removing the spark.es.nodes parameters had no impact on single node results

