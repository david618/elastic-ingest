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

### Azure Tests
- **Az Vms**: 24 VM's (10 Elasticsearch, 10 Spark, 3 Kafka, 1 Test)
- **AKS 1.12**: 14 VM's, k8s 1.12; Advanced Networking; Premium Drives
- **AKS Px**: 14 VM's, k8s 1.12, Portworx (replication factor 3; encrypted)
- **EKS 1.12**: 14 VM's, k8s 1.12, Storage Class: gp2
- **AKS 1.13**: 14 VM's, k8s 1.13; Advanced Networking; Premium Drives
- **AKS 24**: 24 VM's, k8s 1.13; Advanced Networking; Premium Drives
- **EKS 1.13**: 24 VM's, k8s 1.13; Storage Class: gp2

|# es Nodes|Az Vms  |AKS 1.12|AKS Px  |EKS 1.12|AKS 1.13|AKS 24   |EKS 1.13|
|----------|--------|--------|--------|--------|--------|---------|--------|
|1         |83      |        |        |        |        |         |        |
|3         |223     |161     |        |180     |        |         |        |
|5         |248     |236     |102     |265     |        |         |        |
|7         |348     |259     |133     |415     |246     |281      |359     |
|10        |466     |289     |170     |466     |282     |347      |385     |
|20        |938     |        |        |        |        |         |        |

### Portworx Test Results 

- AKS with 25 D16sv3
- Taint/Label/Tollerance/Selector used to keep test code seprate
- Kafka Brokers using 14cpu/50GB mem (keeps Spark Executors off Kafka Broker Node)

#### Test Variations 

Portworx
- Elasticsearch Replication Factor 1 and Kafka Replication Factor 1 (**px1**)
- Elasticsearch Replication Factor 2 and Kafka Replication Factor 2 (**px2**)
- Elasticsearch Replication Factor 3 and Kafka Replication Factor 3 (**px3**)
- Elasticsearch Replication Factor 2 and Kafka Replication Factor 1 (**px-es2-k1**)
- Elasticsearch Replication Factor 2 (io_profile=db_remote) and Kafka Replication Factor 1 (**px-es2r-k1**)
- Elasticsearch Replication Factor 3 and Kafka Replication Factor 1 (**px-es3-k1**)

Azure Managed Premium 
- Elasticsearch Number of Replicas 0 and Kafka Replication Factor 1 (**az1**)
- Elasticsearch Number of Replicas 1 and Kafka Replication Factor 2 (**az2**) (Use: ``run-test-10part-repl2.sh``) 

|Test Variation|Average|Standard Deviation|
|--------------|-------|------------------|
|az1           |404    |9                 |
|px1           |391    |6                 |
|px-es2r-k1    |337    |4                 |
|px2           |311    |11                |
|px-es2-k1     |306    |14                |
|px-es3-k1     |253    |7                 |
|az2           |252    |2                 |
|px3           |238    |13                |

Oberseravtions
- az1 rate (404k/s) is best we've seen on AKS; off AKS on Azure (previous table) was 466k/s with similar number of nodes
- px1 is about the same as az1
- px2 is 20% slower than px1
- px3 is 39% slower than px1; 23% slower than px2 
- az2 is 38% slower than az1

Observations  
- AKS 1.13
  - Ingest rates same as AKS 1.12
- AKS 24
  - 7 Node ingest rate was close to Az Vms
  - 10 node ingest dropped (repeated test several times)
- EKS 1.13
  - 7 node ingest rate was lower (suspect EKS 1.12 7 node rate reported was spuriously high)
  - 10 node ingest was same


## Additional Tests 

- Test AKS using Ultra SSD; 7 and 10 es nodes; 14  nodes
- Enable metrics and try to identify potential performance issues
