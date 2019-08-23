## elastic-ingest

This repo documents ingest rates achieved using Spark to load message from Kakfa to Elasticsearch.

Test Overview
- Java application reads lines from a file; then sends those messages to a Kakfa topic
- Spark application consumes the Kafka Topic; reads the messages and writes them to Elasticsearch
- Monitor tools are used to measure the rate at which messages are written to Kafka and Elasticsearch

![Kafka Spark Elastic Diagram](./KafkaSparkElasticDiagram.jpg)


## Summary of Test Results

VM's size
- Azure: D16s_v3
- AWS: M5.4xlarge

### Test Results 6 Node Cluster

- 6 D16sv3 or M5.4xlarge nodes (16 cores/64 GB mem)
- 1 Node tainted and used as test server
- 2 Elasticsearch Client nodes (7 cpu, 26GB mem each)
- 3 Brokers (2 cpu, 4GB mem each)
- 10 Spark Executors
- 10 Senders (Each sending 25k/s for 10 million)

#### EKS vs. AKS
		
|config |aks   |eks   |%change|
|-------|------|------|-------|
|repl1  |94.92 |131.83|38.89% |
|repl2  |48.30 |68.25 |41.30% |
|px1    |98.75 |127.00|28.61% |
|px2    |83.48 |124.42|49.04% |
|px3	  |67.92 |106.08|56.20% |
|px2-dbr|96.73 |129.82|34.21% |
|px3-dbr|76.73 |113.55|47.99% |

EKS provide 30 to 60 faster ingest than AKS.

#### App vs. Portworx Repl			

|config    |app   |px    |%change|
|----------|------|------|-------|
|AKS repl1 |94.92 |98.75 |4.04%  |
|AKS repl2 |48.30 |96.73 |100.26%|
|EKS repl1 |131.83|127.00|-3.67% |
|EKS repl2 |68.25 |129.82|90.21% |

Ingest rate with Portworx Replication 2 was about two fimes faster than setting Application (Kafka/Elasticsearch) at Replication factor 2.

#### db vs. db_remote			

|config   |db    |db_remote|%change|
|---------|------|---------|-------|
|AKS repl2|83.48 |96.73    |15.87% |
|EKS repl2|124.42|129.82   |4.34%  |
|AKS repl3|67.92 |76.73    |12.97% |
|EKS repl3|106.08|113.55   |7.03%  |

Portworx setting io_profile=db_remote provide better ingest rates thant ip_profile=db.  The performance difference in Azure was 13-16% the performance difference in EKS was 4-7%.

### Test Results 25 Node Cluster

- 25 D16sv3 or M5.4xlarge nodes (16 cores/64 GB mem)
- 3 Node tainted and used as test server
- 10 Elasticsearch Client nodes (14 cpu, 50GB mem each)
- 3 Brokers (14 cpu, 50GB mem each)
- 20 Spark Executors
- 20 Senders (Each sending 25k/s for 10 million)

#### Replication Factor 1

No High Availability

|Configuration                                   |Average|stdev|
|------------------------------------------------|-------|-----|
|EKS Elasticsearch/Kafka Repl 1 (gp2)            |545    |2    |
|EKS with Portworx Repl 1                        |523    |18   |
|AKS Elasticsearch/Kafka Repl 1 (managed-premium)|404    |9    |
|AKS with Portworx Repl 1                        |391    |6    |

#### Replication Factor 2

High Availbility; allows for one node failure.

|Configuration                                   |Average|stdev|
|------------------------------------------------|-------|-----|
|EKS with Portworx Repl 2                        |404    |4    |
|EKS Elasticsearch/Kafka Repl 2 (gp2)            |403    |3    |
|AKS with Portworx Repl 2                        |311    |11   |
|AKS Elasticsearch/Kafka Repl 2 (managed-premium)|252    |2    |

#### Replication Factor 3

High Availbility; allows for two node failure.

|Configuration                                   |Average|stdev|
|------------------------------------------------|-------|-----|
|EKS with Portworx Repl 3                        |351    |26   |
|EKS Elasticsearch/Kafka Repl 3 (gp2)            |274    |6    |
|AKS with Portworx Repl 3                        |238    |13   |
|AKS Elasticsearch/Kafka Repl 3 (managed-premium)|214    |4    |


Observations
- In all tests ingest rate on EKS was 30 to 50% faster than AKS 
- For Replication Factor 2 and 3; Portworx was up to 25% faster than Elasticsearch/Kafka Replication


