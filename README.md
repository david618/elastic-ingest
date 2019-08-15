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

### Test Results 10 Node Elasticsearch

- AKS with 25 D16sv3 or EKS with 25 M5.4xlarge (16 cores and 64GB mem)
- Elasticsearch (Datastore) with 10 nodes
- Three Kafka Brokers using 14cpu/50GB mem (keeps Spark Executors off Kafka Broker Nodes)
- Taint/Label/Tollerance/Selector used to keep test code seprate from what is being tested

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



