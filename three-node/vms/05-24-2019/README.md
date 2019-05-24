

## Test on CentOS VM's


### Create Azure Cluster

Created cluster with three agents using [create-cluster template](../../../install/vms/create-cluster.json)


This created boot (D4sv3) and 3 nodes (D16vs3) a1,a2,a3 (Elasticsearch)

Used add-agents template
- added 3 nodes(D16sv3): a21,a22, and a23 (spark)
- added 3 nodes(D16sv3): a41,a42, and a43 (kafka)
- added 1 node (D16sv3): a81 (test)

### Installed Spark

Under ansible/spark edit hosts and set for a21,a22,a23; use boot as master.

```
bash format-drives.sh
bash install-spark.sh
bash start-spark.sh
```

### Installed Kafka

Under ansible/kafka edit hosts and set a41, a42, and a43

```
bash format-drives.sh
bash install-kafka.sh
bash start-kafka-zoo.sh
```

### Build Sparktest

```
git clone https://github.com/david618/sparktest
cd sparktest
mvn install
```

### Deploy Sparktest

```
cd ansible/spark
bash deploy-sparktest.sh
```

### Build rttest

```
git clone https://githubcom/david618/rttest
cd rttest
mvn install
```

### Setup Test Servers

Edit the hosts files and set ip or name of test server.

```
cd ansible/testservers
bash setup_test_servers.sh
```


### Start Spark Job

```
/opt/spark/bin/spark-submit   \
  --conf spark.executor.cores=2   \]
  --conf spark.cores.max=66   \
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
  spark://boot:7077 1000 a41:9092 group1 planes3 1 a1,a2,a3 9200 - - 9 true false true planes 60s &
```

Watches planes3 Kafka Topic and loads to Elasticsearch Index planes.

Kill from Spark Web UI or kill process. 

### Kafka Topic Monitor (KTM)

``
java -cp rttest/target/rttest.jar com.esri.rttest.mon.KafkaTopicMon a41:9092 planes3 > ktm3.txt &
```

### ElasticIndexMon (EIM)

java -cp rttest/target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://a1:9200/planes 10 6 > eim3.txt &

### Send File to Kafka Topic

```
bash sendPlanes a41:9092 planes3 planes00000 25 250 4
```

Starts 4 instances; each instances will send 250 million lines at 25k/s using planes00000 as a source file to topic planes3 Kafka Broker a41:9092.

Creates output files for each instance (k1.out, k2.out, ...)


You can kill if needed using ``pkill -f send.Kafka``


- Send: 4x25k/s (100k/s)
- KTM: 100k/s
- EIM: 96k/s 


### Repeated Kafka Topic with 33 Partitions


```
/opt/spark/bin/spark-submit \
  --conf spark.executor.cores=2 \
  --conf spark.cores.max=66 \
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
  --conf spark.driver.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml \
  --conf spark.executor.extraJavaOptions=-Dlog4j.configurationFile=/home/spark/sparktest/log4j2conf.xml \
  --conf spark.streaming.kafka.consumer.cache.enabled=false \
  --class  org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar \
  spark://boot:7077 1000 a41:9092 group1 planes33 1 a1,a2,a3 9200 - - 9 true false true planes 60s
```

- Send: 4x25k/s (100k/s)
- KTM: 100k/s
- EIM: Started at 100k/s dropping slowly to 78k/s by end of run 

Observation:  It appears if you have many partitions (e.g. 33) the ingest rate is impacted. It starts off well and slowly drops. The test with 3 partitions provided a steady ingest rate for all 1 billion lines.


