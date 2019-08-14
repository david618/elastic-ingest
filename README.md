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

#### Test Variations 

- **px1**: Elasticsearch Replication Factor 1 and Kafka Replication Factor 1
- **px2**: Elasticsearch Replication Factor 2 and Kafka Replication Factor 2 
- **px3**: Elasticsearch Replication Factor 3 and Kafka Replication Factor 3 
- **px-es2-k1**: Elasticsearch Replication Factor 2 and Kafka Replication Factor 1 
- **px-es3-k1**: Elasticsearch Replication Factor 3 and Kafka Replication Factor 1 
- **px-es1-k3**: Elasticsearch Replication Factor 1 and Kafka Replication Factor 3 
- **px-es2r-k1** Elasticsearch Replication Factor 2 (io_profile=db_remote) and Kafka Replication Factor 1
- **px-rf2-dbr**: Elasticsearch Replication Factor 2 (io_profile=db_remote)
- **px-rf3-dbr** Elasticsearch Replication Factor 3 (io_profile=db_remote)
- **az1**: Elasticsearch Number of Replicas 0 and Kafka Replication Factor 1
- **az2**: Elasticsearch Number of Replicas 1 and Kafka Replication Factor 2 
- **az3**: Elasticsearch Number of Replicas 1 and Kafka Replication Factor 3 
- **gp2**: Google (gp2) default storage class on eks
- **epx-rf2-dbr**: Elasticsearch Replication Factor 2 (io_profile=db_remote)
- **epx-rf3-dbr** Elasticsearch Replication Factor 3 (io_profile=db_remote)

Orderd fastest to slowest (Ingest rates in k/s).

|Test Variation    |platform|Average|Standard Deviation|High Availability|
|------------------|--------|-------|------------------|-----------------|
|**gp2**           |EKS     |545    |2                 |none             |
|**az1**           |AKS     |404    |9                 |none             |
|**epx-rf2-dbr**   |EKS     |404    |11                |1                |
|**px1**           |AKS     |391    |6                 |none             |
|**epx-rf3-dbr**   |EKS     |351    |26                |2                |
|**px-es2r-k1**    |AKS     |337    |4                 |none             |
|**px-rf2-dbr**    |AKS     |324    |11                |1                |
|**px-es1-k3**     |AKS     |324    |13                |none             |
|**px2**           |AKS     |311    |11                |1                |
|**px-es2-k1**     |AKS     |306    |14                |none             |
|**px-rf3-dbr**    |AKS     |263    |7                 |2                |
|**px-es3-k1**     |AKS     |253    |7                 |none             |
|**az2**           |AKS     |252    |2                 |1                |
|**px3**           |AKS     |238    |13                |2                |
|**az3**           |AKS     |214    |4                 |2                |

High Availability
- None: Provide no fault tolerance
- 1: Can withstand one failed node 
- 2: Can withstand two failed nodes 


