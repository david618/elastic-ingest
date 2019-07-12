
## Azure VM's

For a fair comparison of Azure vs. Azure VM's this test
- Uses same number/size of VM's as used in AKS
- Applications (Spark, Kafka, Elasticsearch, Test) deployed on VM's (some on same VM)


#### Setup

Used create-cluster template
- Resource Group: new dj0712a
- Location: West Us 2
- Username: azureuser
- Public Key: Copy and paste Public Key
- Num Agents: 14
- Agent Size: Standard_D16s_v3
- Agent Disk Size GB: 1024
- Boot Server Size: Standard_D4s_v3


Template install CentOS 7.5.

Copied private key to boot

Added ssh to my .ssh/config

```
Host dj0712a
  User azureuser
  HostName 52.183.40.182
  IdentityFile ~/az
  LocalForward 8080 a1:8080
  LocalForward 9200 a5:9200
```

```
sudo yum -y install epel-release
sudo yum -y install git maven
```


git clone https://github.com/david618/ansible


#### Install Spark

Under ansible/spark edit hosts
- bastion: boot
- master: boot
- slave: a1,a2,...,a14



```
bash install-spark.sh
bash start-spark.sh
```

#### Install Elasticsearch

Under ansible/elasticsearch7 edit hosts
- master a5
- data: a6,a7,...,a14

Note: the master is dual roled as master and data.  Result is 10 data nodes; one data node is also acting as master.

```
bash format-drives.sh
bash install-elasticsearch.sh
bash start-elasticsearch.sh
```

#### Install Kafka

Under ansible/kafka edit hosts
- brokers: a2, a3, and a4

```
bash format-drives.sh
bash install-kafka.sh
bash start-kafka-zoo.sh
```

#### Build Sparktest

```
git clone https://github.com/david618/sparktest
cd sparktest
mvn install
```

#### Deploy Sparktest

```
cd ansible/spark
bash deploy-sparktest.sh
```

#### Build rttest

```
git clone https://github.com/david618/rttest
cd rttest
mvn install
```


#### Setup Test Servers

From ansible/testserver Edit the hosts files
- testservers: a1

```
bash setup_test_servers.sh
```

Copy data file down from AWS S3

```
ssh a1
cd rttest
curl -O https://esriplanes.s3.amazonaws.com/lat88/withhashes/planes00000
exit
```

#### Create Kafka Topic

```
ssh a2
sudo su - kafka
./kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --topic planes3 --create --replication-factor 1 --partitions 3
./kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --topic planes10 --create --replication-factor 1 --partitions 10
exit
```

#### Start SparkJob

```
sudo su - spark

/opt/spark/bin/spark-submit   \
  --conf spark.executor.cores=4   \
  --conf spark.cores.max=20   \
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
  spark://boot:7077 1000 a2:9092 group1 planes10 1 a5,a6,a7 9200 - - 10 true false true planes 60s 10000 0 false 
```

#### Kafka Topic Monitor (KTM)

```
ssh a1
java -cp rttest/target/rttest.jar com.esri.rttest.mon.KafkaTopicMon a2:9092 planes10 
```

#### Elastic Index Monitor (EIM)


```
ssh a1
java -cp rttest/target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://a5:9200/planes 10 8 
```

Samples every 10 seconds; collects samples when the rate is increasing.  After 8 samples (80 seconds); the monitor assumes the test is over and outputs a summary.  

The total count should be same as number sent. 

#### Send Data to Kafka

```
ssh a1
cd rttest
bash sendPlanes a2:9092 planes10 planes00000 50 5 8
```

Sends lines from planes00000 to Kafka (a2:9092) topic (planes10) using 8 threads.  Each thread sending 5 million lines at 25k/s. 

You should see a KafkaTopicMon rate of around 200k/s.

#### Collect Results Elastic Index Mon

The following table reports Average Rates

|KTM Rate|EIM Rate|Number Msgs Sent|Number Msgs Ingested|
|--------|--------|----------------|--------------------|
|392 k/s |311 k/s |40 million      |40 million          |
|398 k/s |215 k/s |160 million     |160 million         |
|401 k/s |241 k/s |160 million     |160 million         |

#### Observations
- When testing on Azure with more VM's and separation of tasks (Kafka, Spark, Elasticsearch) rates achieved were higher
  - 10 ES VM's
  - 10 Spark VM's
  - 3 Kafka VM's
  - 1 Test VM
  - Ingest rate was 466k/s  
  - Ingest rate was nearly 2x faster than test above; however, this required 24 VM's instead of 14.
- EKS with 14 M5.4xlarge gave ingest rates of 506k/s [EKS](https://github.com/david618/elastic-ingest/tree/master/multi-node/eks-2019-06-28)

