## Testing on VMs

These tests were done using 3 Elasticsearch nodes using Azure D16v3 VM's.

- [05-03-2019](./05-03-2019): Exploring configuration for best performance. Rates as high as 144k/s using 3 VM's for Elasticsearch, Kafka, Spark, and test.  
- [05-06-2019](./05-06-2019): Repeat test with 3 VM's for each function.  Rate was 190k/s for 80 million. Rate was still dropping so 190k/s does not appear to be sustainable.  VM's were all stopped/deallocated over weekend.  These new VM's appear to be performaning better than the ones test last week.
- [05-24-2019](./05-24-2019): Repeated tests with 3 VM's. Root cause of falling ingest rates is Kafka Topic with 33 partitions; lowered to three got a steady state input of 120k/s.  Tested sending 160k/s; ingest was fairly steady at 130k/s.  
