### Setup

#### Install 25 Cloud Drives Failed

```
./create-tenant.sh dj0802b westus2 25 6 advnet yes
```

Portworx failed to install; collected logs and deleted. 

#### Installed 6 Cloud Drives; then Scaled to 25

```
./create-tenant.sh dj0802b westus2 6 6 advnet yes
```

Then scalled up to 12, then 18, then 25. 

Waiting to make sure portworx installed after each scale.  About 5 to 8 minutes.

Collected ten tests; 

The cloud drives did not start back up after restart over night; collected logs and deleted.

#### Install Portworx without Cloud Drives

```
./create-tenant.sh dj0802b westus2 16 14 advnet no
```

Scaled to 25 nodes.

#### Updated Kafka Resource Requests

Modified the Kafka brokers to request 14 cpu and 50GB of memory. This will cause each broker to use most of a node; and prevent Spark Exectutors from running on same nodes as the Kafka Brokers.

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

Updated the rttest monitor and rttest send to include a selector and tolerance.

```
      tolerations:
      - key: "key"
        operator: "Exists"
        effect: "NoSchedule"
      nodeSelector:
        func: test
```

### Run Tests

The following script will run 25 tests.  The sleep time will need to be adjusted if the ingest time is signficantly different than expected.

```
#!/usr/bin/env bash

topic="planes10"

for runnum in {1..25}; do
  echo "------------------------------------------------------"
  echo ${runnum}

  # Stop Monitors
  kubectl delete -f rttest-mon-kafka-tol.yaml
  kubectl delete -f rttest-mon-es-tol.yaml
  sleep 10

  # Stop Send and Spark Job
  kubectl delete -f rttest-send-kafka-25k-10m-10part-tol.yaml
  kubectl delete -f sparkop-es-2.4.1-10part.yaml
  sleep 60 # Wait a min

  # Recreate Kafka Topic
  # If it exists; delete it
  cnt=$(kubectl exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --list | grep ${topic} | wc -l )

  if [ "${cnt}" -gt 0 ]; then
    # If exists; delete the topic
    kubectl exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic ${topic} --delete
  fi

  # Create Topic
  kubectl exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic ${topic} --create --replication-factor 1 --partitions 10

  if [ "$?" -ne 0 ]; then
    echo "Create Topic Failed; this will happen if some process has an open connection to the topic. Make sure you delete all producers/consumers and try again."
    exit 1
  fi

  # Start Spark Job
  kubectl apply -f sparkop-es-2.4.1-10part.yaml
  sleep 60 # Wait a min

  # Start monitors
  kubectl apply -f rttest-mon-kafka-tol.yaml
  kubectl apply -f rttest-mon-es-tol.yaml
  sleep 60 # Wait a min

  # Start Send
  kubectl apply -f rttest-send-kafka-25k-10m-10part-tol.yaml
  sleep 780 # Wait 12 min  (Assuming rate around of at least 300k/s that would take 666 seconds)

  # Capture Results
  echo "Kafka Logs"
  kubectl logs $(kubectl get pod -l app=rttest-mon-kafka -o name)
  echo "Elasticsearch Logs"
  kubectl logs $(kubectl get pod -l app=rttest-mon-es -o name)
  sleep 10

done
```


### Results

Elasticsearch (es) Portworx Replication Factor and Kafka (k) Portworx Replication Factor.

#### Portworx es-1 and k-1

Average: 391 
Stdev: 6

#### Porworx es-2 and k-1

Average: 306 
Stdev: 14

#### Portworx es-3 and k-1

Average: 253
Stdev: 7





