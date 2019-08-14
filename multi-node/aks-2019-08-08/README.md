### Setup

#### Install Portworx without Cloud Drives

```
./create-tenant.sh dj0805a westus2 16 14 advnet no
```

This gives Portworx access to 14TB of storage attached to 14 nodes. 


AKS Scaled to 25 nodes.


#### Kafka Resource Requests

The Kafka brokers resources request 14 cpu and 50GB of memory. 

This will cause each Kafka broker to use most of a AKS node; prevents Spark Exectutors (requesting 4cpu) from running on same nodes as the Kafka Brokers.

####  Use Kubernetes labels/taints

Looking at pods nothing was deployed on pods 22,23,24.

Added taint and label to those pods.

```
kubectl taint nodes aks-nodepool1-83440018-22 key=test:NoSchedule
kubectl taint nodes aks-nodepool1-83440018-23 key=test:NoSchedule
kubectl taint nodes aks-nodepool1-83440018-24 key=test:NoSchedule
```

```
kubectl label nodes aks-nodepool1-83440018-22 func=test
kubectl label nodes aks-nodepool1-83440018-23 func=test
kubectl label nodes aks-nodepool1-83440018-24 func=test
```

Used rttest monitor and rttest send to include a selector and tolerance.

```
      tolerations:
      - key: "key"
        operator: "Exists"
        effect: "NoSchedule"
      nodeSelector:
        func: test
```

### Run Tests

Used [run-test-10part.sh](../../install/aks/manifests/run-test-10part.sh)

The script repeats the following steps 25 times
- Deletes rttest kafka and es monitors; sleeps 10 seconds
- Deletes rttest send and Spark job; sleeps 60 seconds
- Deletes and recreates the Kafka topic (e.g. planes10); can be changed if desired in the script
- Starts Spark Job (Reads from Kafka Topic and Writes to Elasticsesarch Index); sleeps 60 seconds
- Starts rttest kafka and es monitors; sleeps 60 seconds
- Starts rttest send; sleeps 780 seconds (13 minutes)
- Outputs the logs from rttest kafka and es monitors; sleeep 10 seconds

The total time for the test is about 7 hours.

Using Redirects the output is sent to a file.  For example:

```
bash run-test-10part.sh >> dj0805a-pxrf1-test-201908050942.log &
```

The results are then copies from the log file to a Spreadsheet.  Capturing the Average Rate for each test run. 

The Spreadsheet is used to calculate the average and standard deviation for all of the test runs.


### Test Variations


#### Remove Elasticsearch (Datastore)

```
helm delete --purge datastore-elasticsearch-client
helm delete --purge datastore-elasticsearch-master
kubectl delete pvc -l app=datastore-elasticsearch-client
kubectl delete pvc -l app=datastore-elasticsearch-master
```

#### Remove Gateway (Kafka)

```
helm delete --purge gateway
kubectl delete pvc -l app=cp-kafka
kubectl delete pvc -l app=cp-zookeeper
```

#### Make Configuration Changes

```
vi ../helm-charts/confluent/values-prod.yaml
vi ../stores/datastore/es-client-values.yaml
vi ../stores/datastore/es-master-values.yaml
```

Set the storageClassName and schedulerName.
- There are several example storageClassName's in the config; just uncomment the one you want to test and comment out others
- For Portworx uncomment schedulerName: "stork" for Azure managed Premium comment out schedulerName 


#### Variations

Portworx
- Elasticsearch Replication Factor 1 and Kafka Replication Factor 1 (**px1**)
- Elasticsearch Replication Factor 2 and Kafka Replication Factor 2 (**px2**)
- Elasticsearch Replication Factor 3 and Kafka Replication Factor 3 (**px3**)
- Elasticsearch Replication Factor 2 and Kafka Replication Factor 1 (**px-es2-k1**)
- Elasticsearch Replication Factor 2 (io_profile=db_remote) and Kafka Replication Factor 1 (**px-es2r-k1**)
- Elasticsearch Replication Factor 3 and Kafka Replication Factor 1 (**px-es3-k1**)


Azure Managed Premium 
- Elasticsearch Number of Replicas 0 and Kafka Replication Factor 1 (**az1**)
- Elasticsearch Number of Replicas 1 and Kafka Replication Factor 2 (**az2**) (Use: [run-test-10part-repl2.sh](../../install/aks/manifests/run-test-10part-repl2.sh)) 
- Elasticsearch Number of Replicas 1 and Kafka Replication Factor 3 (**az3**) (Use: [run-test-10part-repl3.sh](../../install/aks/manifests/run-test-10part-repl3.sh)) 


### Results


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
|az3           |214    |4                 |




We need at least 2 replicas for high availability; ideally we'd have 3 replicas spread across 3 Availability zones. 

Obserations
- Highest rates are with one replica; az1 and px1 are about the same
- Using px replication factor of 1,2,3 on Elasticsearch; while holding Kafka at 1 (391,306,253) wasn't much different than using same Replication Factor for Elasticsearch and Kafka (391,311,238).
- Azure Premium drives with Elasticsearch and Kafka set to create two replicas (252) is about 40k/s slower that px2.
- Azure 2 (az2) replicas is 37% slower Azure 1 (az1) replica; Azure 3 (az3) replicas is 47% than Azure 1 (az1) replica. 





