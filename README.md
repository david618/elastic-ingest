# elastic-ingest

This repo documents ingest rates achieved using Spark to load message from Kakfa to Elasticsearch.

Test Overview
- Java application reads lines from a file; then sends those messages to a Kakfa topic
- Spark application consumes the Kafka Topic; reads the messages and writes them to Elasticsearch
- Monitor tools are used to measure the rate at which messages are written to Kafka and Elasticsearch

## Using VM's on Azure


## Using AKS 

