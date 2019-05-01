# One Node Test

In these test one node was used for each component
- Kafka (one broker)
- Spark (one worker)
- Elasticsearch (one node)
- Test Server (one)

For both AKS and VM's these tests used D16v3 type instances.


The ingest rates for both AKS and VM's were about the same.

Ingest rage was about 80k/s at the start and dropped to 60k/s after about 15 minutes.

