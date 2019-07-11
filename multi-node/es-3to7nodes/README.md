## Testing Elasticsearch Ingest Rates scaling from 3 to 7 Data Nodes

### Using This SparkJob

```
---
apiVersion: "sparkoperator.k8s.io/v1beta1"
kind: SparkApplication
metadata:
  name: sparkop-es-2.4.1
  namespace: default
spec:
  arguments:
    - "k8s://https://kubernetes:443"
    - "1000"
    - "gateway-cp-kafka:9092"
    - "group1"
    - "planes3"
    - "1"
    - "datastore-elasticsearch-client-headless"
    - "9200"
    - "-"
    - "-"
    - "3"
    - "true"
    - "false"
    - "true"
    - "planes"
    - "60s"
    - "10000"
    - "0"
    - "false"
  driver:
    coreLimit: "2"
    cores: 2
    javaOptions: -Dlog4j.configurationFile=/opt/spark/work-dir/log4j2conf.xml
    labels:
      version: 2.4.1
    memory: 1024m
    serviceAccount: spark
  executor:
    cores: 4
    instances: 3
    javaOptions: -Dlog4j.configurationFile=/opt/spark/work-dir/log4j2conf.xml
    labels:
      version: 2.4.1
    memory: 5000m
  image: "david62243/sparktest:v0.4-2.4.1"
  imagePullPolicy: Always
  mainApplicationFile: /opt/spark/work-dir/sparktest-full.jar
  mainClass: org.jennings.estest.SendKafkaTopicElasticsearch
  mode: cluster
  restartPolicy:
    type: Always
  sparkConf:
    spark.driver.extraClassPath: "/opt/spark/work-dir/dependency-jars/\\*"
    spark.executor.extraClassPath: "/opt/spark/work-dir/dependency-jars/\\*"
    spark.kubernetes.container.forcePullImage: "true"
    spark.kubernetes.container.image: david62243/sparktest:v0.4-2.4.1
    spark.kubernetes.container.image.pullPolicy: Always
    spark.kubernetes.driver.label.app: kafka-to-elasticsearch
    spark.kubernetes.executor.label.app: kafka-to-elasticsearch
    spark.locality.wait: 60s
    spark.scheduler.mode: FAIR
    spark.streaming.concurrentJobs: "64"
    spark.ui.enabled: "false"
    spark.ui.showConsoleProgress: "false"
    spark.streaming.kafka.consumer.cache.enabled: "false"
    spark.es.batch.size.bytes: "421000000"
    spark.es.batch.size.entries: "50000"
    spark.es.batch.write.refresh: "false"
    spark.es.nodes.discovery: "false"
    spark.es.nodes.data.only: "false"
    spark.es.nodes.wan.only: "true"
  sparkVersion: "2.4.1"
  type: Scala
  ```


```
kubectl apply -f sparkop-es-2.4.1.yaml
```

### Here is the settings from the Index

```
curl http://datastore-elasticsearch-client:9200/planes
```

```
    "settings" : {
      "index" : {
        "refresh_interval" : "60s",
        "number_of_shards" : "3",
        "provided_name" : "planes",
        "max_result_window" : "10000",
        "creation_date" : "1559140873870",
        "number_of_replicas" : "0",
        "uuid" : "lUWEDsSsQ4-N6kwofOOzFA",
        "version" : {
          "created" : "7000099"
        }
      }
    }
```


### Start Elastic Index Mon

```
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8
```

### Start Send

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```
Sending 8x25k/s sending 40 million.  

#### Reset between Each Test

##### Delete Spark Job and Delete Index

```
kubectl delete -f sparkop-es-2.4.1.yaml
curl -XDELETE http://datastore-elasticsearch-client:9200/planes
```

##### Update the Datastore 

```
kubectl edit statefulset datastore-elasticsearch-client
```

Opens in "vi"

Change number of replicas (e.g. change from 2 to 3) and save.  

##### Start SparkJob 

```
kubectl apply -f sparkop-es-2.4.1.yaml
```

Verify index count is zero; you can do this from rttest-mon pod.

```
curl http://datastore-elasticsearch-client:9200/planes/_count?pretty
```

#### Results

Datastore
- 3 masters
- Each client (data/ingest): 14 cpu, 50Gi mem, Heap 26GB


KTM Rate: 200k/s


|Number Data Nodes|EIM Rate|Number AKS Nodes|Spark Op Executors|
|-----------------|--------|----------------|------------------|
|2                |74k/s   |6               |3                 |
|3                |62k/s   |6               |3                 |
|3                |62k/s   |12              |3                 |
|4                |86k/s   |12              |3                 |
|5                |72k/s   |12              |3                 |
|5                |69k/s   |12              |6                 |
|6                |82k/s   |12              |3                 |
|7                |83k/s   |12              |3                 |


#### Observations

The ingest is not scaling with number of data nodes.  

