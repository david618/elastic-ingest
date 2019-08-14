
### Setup

```
./create-tenant.sh dj0802a westus2 16 25 advnet  nopx
```

#### Resources Kafka

In this run I changed Kafka spec to request 14 cpu, 50Gi mem;  This will prevent Spark Executors from running on the Kafka nodes.  

#### Three nodes for Test

Looking at pods nothing was deployed on pods 0,1,and 2.

Added taint and label to those pods.

```
kubectl taint nodes aks-nodepool1-19933601-0 key=test:NoSchedule
kubectl taint nodes aks-nodepool1-19933601-1 key=test:NoSchedule
kubectl taint nodes aks-nodepool1-19933601-2 key=test:NoSchedule
```

```
kubectl label nodes aks-nodepool1-19933601-0 func=test
kubectl label nodes aks-nodepool1-19933601-1 func=test
kubectl label nodes aks-nodepool1-19933601-2 func=test
```

### Create Kafka Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes10 --create --replication-factor 1 --partitions 10
```

### Increase Datastore 10 nodes

```
kubectl edit statefulset datastore-elasticsearch-client
```

### Start Monitors

These versions include node selectors and toleranances to run on test nodes.

```
kubectl apply -f rttest-mon-kafka-tol.yaml
kubectl apply -f rttest-mon-es-tol.yaml
```

### Ran SparkOperator

```
kubectl apply -f sparkop-es-2.4.1-10part.yaml
```

Wait for sparkop to start

### Run Send

```
kubectl apply -f rttest-send-kafka-25k-10m-10part-tol.yaml
```

This will send 200 million at 500k/s  


Spark Job: 20 executors
Number Patitions: 10

### Batch Loop

Created Bash script to run the test 25 times.

**run-test-10part.sh**

```
#!/usr/bin/env bash

for runnum in {1..25}; do
  echo "------------------------------------------------------"
  echo ${runnum}
  kubectl delete -f rttest-send-kafka-25k-10m-10part-tol.yaml
  kubectl delete -f sparkop-es-2.4.1-10part.yaml
  sleep 60 # Wait a min
  kubectl apply -f sparkop-es-2.4.1-10part.yaml
  sleep 60 # Wait a min
  kubectl apply -f rttest-send-kafka-25k-10m-10part-tol.yaml
  sleep 660 # Wait 10 min  (Assuming rate around of at least 300k/s that would take 666 seconds)

  kubectl logs rttest-mon-kafka-58ccb598dd-wnqms | tail
  kubectl logs rttest-mon-es-7f7f5ff9db-4bn68 | tail

done
```

### Run Test Script

```
bash run-test-10part.sh > run-test-10part.log &
```


### Follow Logs 

During a run you can follow the logs

```
kubectl logs $(kubectl get pod -l app=rttest-mon-es -o name) -f
kubectl logs $(kubectl get pod -l app=rttest-mon-kafka -o name) -f
```

### Results

The script should outputs logs of monitors; so you should be able to see the final results of each run in ``run-test-10part.log``.

You could also follow the logs if desired (e.g. kubectl logs rttest-mon-es-7f7f5ff9db-4bn68 -f ).


Tests started at 1130 Central Time on Saturday August 3.

Average: 386 
Standard Deviation: 35















