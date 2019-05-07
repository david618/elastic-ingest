
The VM version uses -Xmx1G -Xms1G for Kafka and -Xmx512M -Xms512M for zookeeper.

#### Kafka

values-label.yaml includes nodeSelector

```
  nodeSelector:
    func: kafka
```

```
helm install --values ../cp-helm-charts/values-label.yaml --name gateway ../cp-helm-charts
```

#### Test Components

```
nodeSelector:
  func: test
```

```
kubectl apply -f rttest-send-label.yaml
kubectl apply -f sparktest-label.yaml   
```

#### Datastore

```
nodeSelector:
  func: es
```

```
helm install --values ../datastore/elasticsearch/master-values-label.yaml --name datastore-elasticsearch-master ../datastore/elasticsearch 
helm install --values ../datastore/elasticsearch/client-values-label.yaml --name datastore-elasticsearch-client ../datastore/elasticsearch
```

### Create Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes9 --create --replication-factor 1 --partitions 9
```

### Spark Job

Add node selector.

--conf spark.kubernetes.node.selector.func=spark

kubectl exec -it sparktest-688c687f98-mt47h tmux

```
/opt/spark/bin/spark-submit \
--master k8s://https://kubernetes:443 \
--deploy-mode cluster \
--conf spark.executor.instances=9 \
--conf spark.executor.cores=5 \
--conf spark.executor.memory=5000m \
--conf spark.es.batch.size.bytes=421000000 \
--conf spark.es.batch.size.entries=50000 \
--conf spark.es.batch.write.refresh=false \
--conf spark.streaming.concurrentJobs=64 \
--conf spark.scheduler.mode=FAIR \
--conf spark.locality.wait=0s \
--conf spark.streaming.kafka.consumer.cache.enabled=false \
--conf spark.kubernetes.container.image=david62243/sparktest:v0.4-2.3.2 \
--conf spark.kubernetes.container.forcePullImage=true \
--conf spark.kubernetes.driver.label.appname=sparktest-es \
--conf spark.kubernetes.executor.label.appname=sparktest-es \
--conf spark.kubernetes.node.selector.func=spark \
--class org.jennings.estest.SendKafkaTopicElasticsearch local:///opt/spark/work-dir/sparktest-full.jar \
k8s://https://kubernetes:443 1000 gateway-cp-kafka:9092 group1 planes9 1 \
datastore-elasticsearch-client-headless 9200 - - 9 true false true planes 60s 10000 0 false
```

#### Pod Placement

```
kubectl get pods -o wide
```

```
datastore-elasticsearch-client-0                                                          1/1     Running   0          8m57s   10.244.4.10   aks-nodepool1-64873208-7    <none>
datastore-elasticsearch-client-1                                                          1/1     Running   0          8m57s   10.244.3.9    aks-nodepool1-64873208-8    <none>
datastore-elasticsearch-client-2                                                          1/1     Running   0          8m57s   10.244.6.7    aks-nodepool1-64873208-6    <none>
datastore-elasticsearch-master-0                                                          1/1     Running   0          10m     10.244.4.9    aks-nodepool1-64873208-7    <none>
datastore-elasticsearch-master-1                                                          1/1     Running   0          10m     10.244.6.6    aks-nodepool1-64873208-6    <none>
datastore-elasticsearch-master-2                                                          1/1     Running   0          10m     10.244.3.8    aks-nodepool1-64873208-8    <none>
gateway-cp-kafka-0                                                                        2/2     Running   1          23m     10.244.5.6    aks-nodepool1-64873208-5    <none>
gateway-cp-kafka-1                                                                        2/2     Running   1          23m     10.244.8.7    aks-nodepool1-64873208-3    <none>
gateway-cp-kafka-2                                                                        2/2     Running   0          22m     10.244.1.9    aks-nodepool1-64873208-4    <none>
gateway-cp-kafka-connect-64877ffd97-fmpxk                                                 2/2     Running   1          23m     10.244.8.6    aks-nodepool1-64873208-3    <none>
gateway-cp-zookeeper-0                                                                    2/2     Running   0          23m     10.244.1.8    aks-nodepool1-64873208-4    <none>
gateway-cp-zookeeper-1                                                                    2/2     Running   0          23m     10.244.8.8    aks-nodepool1-64873208-3    <none>
gateway-cp-zookeeper-2                                                                    2/2     Running   0          22m     10.244.5.7    aks-nodepool1-64873208-5    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-driver   1/1     Running   0          3m45s   10.244.7.7    aks-nodepool1-64873208-1    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-1   1/1     Running   0          3m37s   10.244.2.6    aks-nodepool1-64873208-0    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-2   1/1     Running   0          3m37s   10.244.7.8    aks-nodepool1-64873208-1    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-3   1/1     Running   0          3m37s   10.244.2.7    aks-nodepool1-64873208-0    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-4   1/1     Running   0          3m37s   10.244.7.9    aks-nodepool1-64873208-1    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-5   1/1     Running   0          3m37s   10.244.9.4    aks-nodepool1-64873208-2    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-6   1/1     Running   0          2m55s   10.244.2.8    aks-nodepool1-64873208-0    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-7   1/1     Running   0          2m55s   10.244.9.6    aks-nodepool1-64873208-2    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-8   1/1     Running   0          2m56s   10.244.9.5    aks-nodepool1-64873208-2    <none>
org-jennings-estest-sendkafkatopicelasticsearch-90db77034d7c3cae9fb1b60b2110aa3b-exec-9   0/1     Pending   0          2m55s   <none>        <none>                      <none>
rttest-send-0                                                                             1/1     Running   0          16m     10.244.0.15   aks-nodepool1-64873208-11   <none>
rttest-send-1                                                                             1/1     Running   0          16m     10.244.11.5   aks-nodepool1-64873208-9    <none>
rttest-send-2                                                                             1/1     Running   0          15m     10.244.10.8   aks-nodepool1-64873208-10   <none>
sparktest-688c687f98-mt47h                                                                1/1     Running   0          19m     10.244.10.7   aks-nodepool1-64873208-10   <none>
```

The driver is using enough cpu on node 1 that the exec cannot start.


Took this line out: --conf spark.executor.cores=5 \

```
/opt/spark/bin/spark-submit \
--master k8s://https://kubernetes:443 \
--deploy-mode cluster \
--conf spark.executor.instances=9 \
--conf spark.executor.memory=5000m \
--conf spark.es.batch.size.bytes=421000000 \
--conf spark.es.batch.size.entries=50000 \
--conf spark.es.batch.write.refresh=false \
--conf spark.streaming.concurrentJobs=64 \
--conf spark.scheduler.mode=FAIR \
--conf spark.locality.wait=0s \
--conf spark.streaming.kafka.consumer.cache.enabled=false \
--conf spark.kubernetes.container.image=david62243/sparktest:v0.4-2.3.2 \
--conf spark.kubernetes.container.forcePullImage=true \
--conf spark.kubernetes.driver.label.appname=sparktest-es \
--conf spark.kubernetes.executor.label.appname=sparktest-es \
--conf spark.kubernetes.node.selector.func=spark \
--class org.jennings.estest.SendKafkaTopicElasticsearch local:///opt/spark/work-dir/sparktest-full.jar \
k8s://https://kubernetes:443 1000 gateway-cp-kafka:9092 group1 planes9 1 \
datastore-elasticsearch-client-headless 9200 - - 9 true false true planes 60s 10000 0 false
```

Looking at describe the memory is limited to 5500Mi; but the cpu is unlimited.

The request was for 1 cpu.



#### ElasticIndexMon

```
kubectl exec -it rttest-send-0 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client-headless:9200/planes 10 12
```

#### KafkaTopicMon

```
kubectl exec -it rttest-send-1 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes9
```

#### Send Kafka
```
kubectl exec -it rttest-send-2 tmux
cd /opt/rttest
bash sendPlanes gateway-cp-kafka:9092 planes9 planes00000 200 75 1
```

#### Reults

##### KafkaTopicMon

Steady at 200k/s

##### ElasticIndexMon

|Query Number|Sample Number|Epoch (ms)    |Time (s) |Count             |Linear Reg. Rate  |Rate From Previous|Rate From First   |
|------------|-------------|--------------|---------|------------------|------------------|------------------|------------------|
|          1 |           1 |1556910344404 |       0 |          240,015 |                  |                  |                  |
|          2 |           2 |1556910354203 |       9 |          831,694 |           60,382 |           60,382 |           60,382 |
|          3 |       ***** |1556910364211 |      19 |          831,694 |           60,382 |                0 |           29,872 |
|          4 |       ***** |1556910374116 |      29 |          831,694 |           60,382 |                0 |           19,914 |
|          5 |       ***** |1556910384287 |      39 |          831,694 |           60,382 |                0 |           14,835 |
|          6 |       ***** |1556910394214 |      49 |          831,694 |           60,382 |                0 |           11,879 |
|          7 |       ***** |1556910404196 |      59 |          831,694 |           60,382 |                0 |            9,896 |
|          8 |       ***** |1556910413724 |      69 |          831,694 |           60,382 |                0 |            8,535 |
|          9 |           3 |1556910424232 |      79 |        1,367,725 |           11,726 |            7,654 |           14,127 |
|         10 |           4 |1556910433792 |      89 |        2,269,870 |           16,980 |           94,367 |           22,708 |
|         11 |           5 |1556910444240 |      99 |        2,452,840 |           18,669 |           17,512 |           22,165 |
|         12 |       ***** |1556910454051 |     109 |        2,452,840 |           18,669 |                0 |           20,181 |
|         13 |       ***** |1556910464052 |     119 |        2,452,840 |           18,669 |                0 |           18,494 |
|         14 |       ***** |1556910474261 |     129 |        2,452,840 |           18,669 |                0 |           17,040 |
|         15 |       ***** |1556910483808 |     139 |        2,452,840 |           18,669 |                0 |           15,873 |
|         16 |       ***** |1556910494214 |     149 |        2,452,840 |           18,669 |                0 |           14,771 |
|         17 |           6 |1556910504145 |     159 |        3,020,631 |           16,960 |            9,478 |           17,407 |
|         18 |           7 |1556910513915 |     169 |        3,588,741 |           17,780 |           58,148 |           19,755 |
|         19 |           8 |1556910523863 |     179 |        4,160,896 |           19,109 |           57,515 |           21,848 |
|         20 |       ***** |1556910534032 |     189 |        4,160,896 |           19,109 |                0 |           20,677 |
|         21 |       ***** |1556910543973 |     199 |        4,160,896 |           19,109 |                0 |           19,647 |
|         22 |       ***** |1556910553879 |     209 |        4,160,896 |           19,109 |                0 |           18,718 |
|         23 |       ***** |1556910564058 |     219 |        4,160,896 |           19,109 |                0 |           17,850 |
|         24 |       ***** |1556910573884 |     229 |        4,160,896 |           19,109 |                0 |           17,086 |
|         25 |           9 |1556910583985 |     239 |        4,556,346 |           18,170 |            6,577 |           18,016 |
|         26 |          10 |1556910594240 |     249 |        5,350,997 |           18,868 |           77,489 |           20,457 |
|         27 |          11 |1556910604200 |     259 |        5,951,400 |           19,839 |           60,281 |           21,984 |


Same result as without labels.




