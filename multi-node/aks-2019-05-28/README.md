
## Moving Components off AKS

Goal is to try to isolate what is impacting performance.  

- Everything on AKS:  50-60k/s
- Elasticsearch off AKS: 60k/s
- Elasticsearch and Kafka off AKS: 60k/s
- Kakfa and Spark off AKS sending to ES on AKS: 80/s
- Elasticsearch, Spark, and Kafka off AKS: 90k/s (Over 100k/s when given more Spark Executors)

Spark on AKS seems to be contributing to the performance degradation. 

### Test Setup

- AKS: 6 Nodes D16sv3
- A4IOT Installed: Latest (28May19)
- Datastore: 3 masters / 2 data 

### Deploy Spark Job

Using [sparkop-es-2.4.1.yaml](../../install/aks/manifests/sparkop-es-2.4.1.yaml)
- drivers: 4 cores, 1024MB mem
- exec: 4 cores, 5000MB mem, 3 instances

### Deploy rttest-mon

Use [rttest-mon.yaml](../../install/aks/manifests/rttest-mon.yaml)

```
kubectl apply -f rttest-mon.yaml
```

### EIM Mon

```
kubectl exec -it rttest-mon-2 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 6
```

### KTM Mon

```
kubectl exec -it rttest-mon-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```

### Start Send

```
kubectl apply -f rttest-send-kafka-25k-10m.yaml
```

Deployment configured to use four instances; expected total rate is 100k/s, sending 40 million total messages.

To restart: ```kubectl delete pod -l app=rttest-send-kafka-25k-10m```


### Results

- KTM: 100k/s
- EIM: 50k/s


#### Increasing Driver Cores from 4 to 8

Changes
- drivers: 4 cores, 1024MB mem
- exec: 8 cores, 5000MB mem, 3 instances
- Also added coreLimit and memoryOverhead parameters. This changes the pods from Burstable to Guaranteed.

Results
- KTM: 100k/s
- EIM: 56k/s

#### Change External Elasticsearch

Added three D16sv3 nodes to AKS Managed Cluster (outside of k8s); centos 7.5.

Installed Elasticsearch 7 using Ansible.

Configure sparkop to use external es.

```
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://10.240.0.10:9200/planes 10 6
```

This removes Elasticsearch from k8s.

Results:
- KTM: 100k/s
- EIM: 60k/s


### Elasticsearch and Kafka External to AKS

Added three more nodes (a41,a42, and a43); installed Kafka using Ansible (D16sv3)

Modified SparkOp Job to use external kafka and external elasticsearch.

Created rttest-send-a41-25k-10m.yaml; sends to a41.

Results
- KTM: 100k/s
- EIM: 60k/s


### Kafka, Spark, and Elasticsearch External to AKS

Added four more nodes 
- a20: D4sv3 (Spark Master)
- a21,a22, and a23: D16sv3 (Spark Data)
- CentOS 7.5
- Installed Spark using Ansible

Compliled and deployed Sparktest to nodes

```
/opt/spark/bin/spark-submit   \
  --conf spark.executor.cores=4   \
  --conf spark.cores.max=12   \
  --conf spark.executor.memory=5000m   \
  --conf spark.es.batch.size.bytes=421000000   \
  --conf spark.es.batch.size.entries=50000   \
  --conf spark.es.batch.write.refresh=false   \
  --conf spark.es.nodes.discovery=false   \
  --conf spark.es.nodes.data.only=false   \
  --conf spark.es.nodes.wan.only=true   \
  --conf spark.streaming.concurrentJobs=64   \
  --conf spark.scheduler.mode=FAIR   \
  --conf spark.locality.wait=0s   \
  --conf spark.driver.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.executor.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.streaming.kafka.consumer.cache.enabled=false   \
  --class  org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar   \
  spark://a20:7077 1000 a41:9092 group1 planes3 1 a1 9200 - - 3 true false true planes 60s
```

Same resources as Spark on AKS (3 instances each with 4 cores and 5000m of memory).

**NOTE:** Spark cannot access the Kafka on AKS. When connecting to Kafka; Kafka responses with IP's to brokers.  On AKS these IP's are internal; so clients external to AKS cannot connect.  It is possible to configure Kafka to be externally consumable; but haven't figured it out yet.

Restarted sender on AKS. Sending at 100k/s.

Results
- KTM: 100k/s
- EIM: 87k/s


##### Change Sending 8x25k/s

Results
- KTM: 200k/s
- EIM: 100k/s


##### Change SparkJob to use up to 24 cores (4 per executor) instead of 12.

Results
- KTM: 200k/s
- EIM: 133k/s 


2nd Run
- KTM: 200k/s
- EIM: 110k/s


#### Kafka External and Spark External 

Send to Elasticsearch on AKS.  Only Spark Job and Sender running on K8S.

Create K8S service for Elasticesearch; to allow access from other nodes in the resource group.

```
---
apiVersion: v1
kind: Service
metadata:
  name: es-0
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 9200
  selector:
    statefulset.kubernetes.io/pod-name: datastore-elasticsearch-client-0
---
apiVersion: v1
kind: Service
metadata:
  name: es-1
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 9200
  selector:
    statefulset.kubernetes.io/pod-name: datastore-elasticsearch-client-1
```

Look up IP's; should be External IP as 10.240.0.x.  (e.g. kubectl get svc)

Run Spark Job on External Kafka.

```
/opt/spark/bin/spark-submit   \
  --conf spark.executor.cores=4   \
  --conf spark.cores.max=24   \
  --conf spark.executor.memory=5000m   \
  --conf spark.es.batch.size.bytes=421000000   \
  --conf spark.es.batch.size.entries=50000   \
  --conf spark.es.batch.write.refresh=false   \
  --conf spark.es.nodes.discovery=false   \
  --conf spark.es.nodes.data.only=false   \
  --conf spark.es.nodes.wan.only=true   \
  --conf spark.streaming.concurrentJobs=64   \
  --conf spark.scheduler.mode=FAIR   \
  --conf spark.locality.wait=0s   \
  --conf spark.driver.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.executor.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.streaming.kafka.consumer.cache.enabled=false   \
  --class  org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar   \
  spark://a20:7077 1000 a41:9092 group1 planes3 1 10.240.0.20 9200 - - 3 true false true planes 60s
```

Sending at 8x25k/s

Results:
- KTM: 200k/s
- EIM: 77k/s


**NOTE:** Datastore on AKS has two nodes and off AKS had 3.  

##### Increased to 3 data nodes for AKS datastore.

Results:
- KTM: 200k/s
- EIM: 82k/s

##### Sending to all three Elasticsearch Endpoints


```
/opt/spark/bin/spark-submit   \
  --conf spark.executor.cores=4   \
  --conf spark.cores.max=24   \
  --conf spark.executor.memory=5000m   \
  --conf spark.es.batch.size.bytes=421000000   \
  --conf spark.es.batch.size.entries=50000   \
  --conf spark.es.batch.write.refresh=false   \
  --conf spark.es.nodes.discovery=false   \
  --conf spark.es.nodes.data.only=false   \
  --conf spark.es.nodes.wan.only=true   \
  --conf spark.streaming.concurrentJobs=64   \
  --conf spark.scheduler.mode=FAIR   \
  --conf spark.locality.wait=0s   \
  --conf spark.driver.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.executor.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.streaming.kafka.consumer.cache.enabled=false   \
  --class  org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar   \
  spark://a20:7077 1000 a41:9092 group1 planes3 1 10.240.0.20,10.240.0.21,10.240.0.22 9200 - - 3 true false true planes 60s
```

Results:
- KTM: 200k/s
- EIM: 83k/s


### Added Three Additional Nodes to AKS

Increased from 6 to 9 D16sv3 nodes.


```
/opt/spark/bin/spark-submit   \
  --conf spark.executor.cores=4   \
  --conf spark.cores.max=12   \
  --conf spark.executor.memory=5000m   \
  --conf spark.es.batch.size.bytes=421000000   \
  --conf spark.es.batch.size.entries=50000   \
  --conf spark.es.batch.write.refresh=false   \
  --conf spark.es.nodes.discovery=false   \
  --conf spark.es.nodes.data.only=false   \
  --conf spark.es.nodes.wan.only=true   \
  --conf spark.streaming.concurrentJobs=64   \
  --conf spark.scheduler.mode=FAIR   \
  --conf spark.locality.wait=0s   \
  --conf spark.driver.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.executor.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml   \
  --conf spark.streaming.kafka.consumer.cache.enabled=false   \
  --class  org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar   \
  spark://a20:7077 1000 a41:9092 group1 planes3 1 a1 9200 - - 3 true false true planes 60s
```

Only thing on AKS was rttest-send; previous EIM results today gave 110k/s and 133k/s.

Results:
- KTM: 200k/s
- EIM: 105k/s


