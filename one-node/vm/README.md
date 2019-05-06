
#### Create Cluster

Cluster named: dj0430k

Used [dcosee-1zone](../../install/vms/dcossee-1zone.json) template to create a cluster
- 1 master (m1):  spark master  D8
- 1 agent (a1): spark worker (with 1TB drive) D16
- 1 public agent (p1): test server  D16

Used [add-agent template](../../install/vms/add-agents.json) to add additional nodes
- 1 agent (a41): kafka
- 1 agent (a101): elasticsearch

Total Cost: Based on Azure Cost Calculator $3,201.28/mo

Identified Boot IP:  52.247.217.84

Copied my private key to the boot server and copied the key to ```.ssh/id_rsa```

#### Boot Setup

```
yum install epel-release
yum install git maven
git clone https://github.com/david618/ansible
```

#### Install Kafka

Set hosts files.  One broker a41.

```
bash format-drives.sh
bash install-kafka.sh
```


#### Install Spark

Set hosts file. Master m1 and Worker a1.

```
bash format-drives.sh
bash install-spark.sh

bash start-spark.sh
```

#### Install Elasticsearch 7

Set hosts file.  One node a101.

```
bash format-drives.sh
bash install-elasticsearch.sh

bash start-elasticsearch.sh
```

#### Deploy rttest to Test Servers

```
cd ~
git clone https://github.com/david618/rttest
cd rttest
mvn install
```

```
cd ~
tar cvzf rttest-files.tgz rttest/target/rttest-full.jar rttest/target/rttest.jar rttest/target/lib/* rttest/sendPlanes
```


Use Ansible to configure test server(s).

Edit and set hosts file.

```
bash setup_testservers.sh
```

#### Download Test Data 

Secure shell to boot server.


```
ssh p1
cd rttest
curl -O https://s3.amazonaws.com/esriplanes/lat88/withhashes/planes00000
```


#### Deploy sparktest to Spark Servers

```
cd ~
git clone https://github.com/david618/sparktest
cd sparktest
mvn install
```

Create deployment Archive

```
cd ~
tar cvzf sparktest-files.tgz sparktest/target/*.jar sparktest/target/dependency-jars/* sparktest/log4j2conf.xml 
```

From Ansible spark

```
bash deploy-sparktest.sh
```


#### Create Kafka Topic

```
ssh a41
sudo su - kafka
./kafka/bin/kafka-topics.sh --zookeeper a41:2181 --topic planes3 --create --replication-factor 1 --partitions 3
```

#### Run Spark Job

```
ssh m1
sudo su - spark
```

Sparktest Command


```
/opt/spark/bin/spark-submit \
--conf spark.executor.cores=1 \
--conf spark.cores.max=9 \
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
--class org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar \
spark://m1:7077 1000 a41:9092 group1 planes3 1 \
a101 9200 - - 3 true false true planes 60s 10000 0 false
```

#### Elastic Index Mon (EIM)

Secure shell to boot from another terminal.

```
ssh p1
cd rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://a101:9200/planes 60
```

#### Kafka Topic Mon (KTM)

Secure shell to boot from another terminal.

```
ssh p1
cd rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon a41:9092 planes3
```

#### Send Kafka

```
cd rttest
java -cp target/rttest.jar com.esri.rttest.send.Kafka a41:9092 planes3 planes00000 250000 50000000
```

#### Results

Send: 250k/s
KTM: 250k/s
EIM: 99k/s at 1 min; 75k/s at 10 min
Average: 75k/s; Linear Regression: 75k/s Standard Error: 2.63



Note: About the same as k8s.   


### Longer Test at 100k/s


#### Using 3 instance with 3 cores each vs.s 9 instances with 1 core each

```
/opt/spark/bin/spark-submit \
--conf spark.executor.cores=3 \
--conf spark.cores.max=9 \
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
--class org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar \
spark://m1:7077 1000 a41:9092 group1 planes3 1 \
a101 9200 - - 3 true false true planes 60s 10000 0 false
```


#### Results

Send: 100k/s
KTM: 100k/s
EIM: 83k/s at 1 min; 66k/s at 10 min; 60k/s at 20 min; 57k/s at 30 min; 53k/s at 35 min
Average: 54 k/s; Linear Regression: 54 k/s Standard Error: 0.72 


#### Taking out es.nodes from conf.


Removing

```
--conf spark.es.nodes.discovery=false \
--conf spark.es.nodes.data.only=false \
--conf spark.es.nodes.wan.only=true \
```


```
/opt/spark/bin/spark-submit \
--conf spark.executor.cores=1 \
--conf spark.cores.max=9 \
--conf spark.executor.memory=5000m \
--conf spark.es.batch.size.bytes=421000000 \
--conf spark.es.batch.size.entries=50000 \
--conf spark.es.batch.write.refresh=false \
--conf spark.streaming.concurrentJobs=64 \
--conf spark.scheduler.mode=FAIR \
--conf spark.locality.wait=0s \
--class org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar \
spark://m1:7077 1000 a41:9092 group1 planes3 1 \
a101 9200 - - 3 true false true planes 60s 10000 0 false
```

Send: 1x100k/s
KTM: 100k/s
EIM
  - 78k/s at 1 min; 70k/s at 10 min
  - Average: 66k/s
  - Linear Regression: 69k/s with standard error 1.82



