## Removing Parts from AKS to External

Installed A4IOT.  Added additional nodes to Managed Cluster and installed Kafka, Spark, and Elasticsearch.


### Create Elasticsearch Internal Load Balancer

Create Internal Load Balancer to allow access to Elasticsearch from other nodes in cluster.

```
---
apiVersion: v1
kind: Service
metadata:
  name: es
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 9200
  selector:
    app: datastore-elasticsearch-client
```

###  Spark Operator Job

This is the Spark Operator Job ran when testing everything on AKS.


```
---
apiVersion: "sparkoperator.k8s.io/v1beta1"
kind: SparkApplication
metadata:
  name: sparkop-es-2.4.0
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
    coreLimit: "4"
    cores: 2
    javaOptions: -Dlog4j.configurationFile=/opt/spark/work-dir/log4j2conf.xml
    labels:
      version: 2.4.0
    memory: 1024m
    serviceAccount: spark
  executor:
    cores: 4
    instances: 3
    javaOptions: -Dlog4j.configurationFile=/opt/spark/work-dir/log4j2conf.xml
    labels:
      version: 2.4.0
    memory: 5000m
  image: "david62243/sparktest:v0.5-2.4.0"
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
    spark.kubernetes.container.image: david62243/sparktest:v0.5-2.4.0
    spark.kubernetes.container.image.pullPolicy: Always
    spark.kubernetes.driver.label.app: kafka-to-elasticsearch
    spark.kubernetes.executor.label.app: kafka-to-elasticsearch
    spark.locality.wait: 60s
    spark.scheduler.mode: FAIR
    spark.streaming.concurrentJobs: "4"
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

### Spark Submit 

This was used to run Spark Job on Spark Nodes (not no k8s)

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
  spark://a20:7077 1000 a41:9092 group1 planes3 1 10.240.0.25 9200 - - 3 true false true planes 60s

```

### Test Results

In each test 40 million messages were sent.  


  |Number of Data Nodes|SparkOp AKS|External Spark|Kafka Partitions|Executors|
  |--------------------|-----------|--------------|----------------|---------|
  |2                   |74         |84            |3               |3        |
  |5                   |85         |93            |3               |3        |
  |5                   |81         |87            |5               |3        |
  |5                   |85         |105           |5               |5        |

**Note:** Break. Overnight deallocated nodes; restarted in morning.  

  |Number of Data Nodes|SparkOp AKS|External Spark|Kafka Partitions|Executors|
  |--------------------|-----------|--------------|----------------|---------|
  |5                   |73         |107           |5               |5        |
  
Observations
- For SparkOp AKS there was no improvement in performance from 2 to 5.
- For External Spark there was a 16% improvement when more than double the nodes.
- While there appears to be an Elasticsearch Performance issue there may also be a Spark Performance Issue.


Tested running send Kafka outside of k8s to External Kafka consumed by external Spark writing to Elasticserarch on k8s.  The ingest to Elasticsearch was 101k/s; sending from k8s was nearly the same 105k/s from yesterday.  This eliminates the sender running on k8s as performance problem.


### Putting everything on external nodes; including Elasticsearch.


|Number of Data Nodes|EIM Rate|Kafka Partitions|Executors|
|--------------------|--------|----------------|---------|
|3                   |125     |3               |3        |
|3                   |122     |5               |3        |
|5                   |149     |5               |5        |


Observations
- Elasticsearch not on k8s performs 30% faster
- Results are slower than we saw during our earlier tests.  Earlier tests 3-node near 180k/s and 5-node near 240k/s

