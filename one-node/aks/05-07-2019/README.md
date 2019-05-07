### AKS One Node Test


#### Install AKS

The following Bash script requires you have Azure cli, kubectl, and helm installed on your computer.

You can run this from a Mac or use the [david62243/aks-admin](https://cloud.docker.com/u/david62243/repository/docker/david62243/aks-admin) Docker Image.  The Docker image is based on Ubuntu 18.04 and already has the azcli, kubectl, and helm installed.  (e.g.  docker run -it david62243/aks-admin:v0.2). 

```
bash install-aks-10.sh dj0507 westus2 16 4
```


#### Label Nodes

**NOTE:** I've tested without labeling nodes too; however, to keep the test tools separate from Kafka, Spark, and Elasticsearch labels are needed.  


**NOTE:** Tried to manually add a VM to AKS Managed Cluster; however, connecting to Kafka was problematic. When advertising Kafka brokers send internal names or IP addresses which are not accessible from outside of Kubernetes. It is possible; but will require more research.

```
kubectl get nodes
NAME                       STATUS   ROLES   AGE     VERSION
aks-nodepool1-25663880-0   Ready    agent   6m40s   v1.12.7
aks-nodepool1-25663880-1   Ready    agent   6m41s   v1.12.7
aks-nodepool1-25663880-2   Ready    agent   6m46s   v1.12.7
aks-nodepool1-25663880-3   Ready    agent   6m44s   v1.12.7
```

```
kubectl label node aks-nodepool1-25663880-0 func=spark
kubectl label node aks-nodepool1-25663880-1 func=kafka
kubectl label node aks-nodepool1-25663880-2 func=es
kubectl label node aks-nodepool1-25663880-3 func=test
```


#### Install Kafka 

Created ```single-node-labels.yaml```

To cp-zookeeper and cp-kafka added 

```
  nodeSelector:
    func: kafka
```

In cp-zookeeper set servers to "1"

In cp-kafka set brokers to "1" and added

```
  configurationOverrides:
    "offsets.topic.replication.factor": "1"
```

Set all other components enabled to false.


Installed using helm.

```
helm install --values ../cp-helm-charts/single-node-labels.yaml --name gateway ../cp-helm-charts
```

**NOTE:** I've also tested with Portworx drives which gave similar results.   (Verify!!!)

#### Install Elasticsearch

Created ```single-node-labels.yaml``` for Elasticsearch

Configured 
- esJavaOpts: "-Xmx26g -Xms26g"
- resources not set so it will deploy as burstable and use entire node

**NOTE:** Tried setting resources to 14 cpu 56Gi memory; however, that failed to deploy insufficient memory.

```
helm install --values ../datastore/elasticsearch/single-node-labels.yaml --name datastore ../datastore/elasticsearch
```

#### Deploy Test Tools

```
kubectl apply -f rttest-send-labels.yaml
kubectl apply -f sparktest-labels.yaml
```

We'll run monitor tools from rttest-send and start spark jobs using sparktest.

In order to run jobs on k8s the default user needs an RBAC setting.

```
kubectl apply -f default-service-account-rbac.yaml
```


#### Create Kafka Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes9 --create --replication-factor 1 --partitions 9
```


#### Run Spark Job

```
kubectl exec -it sparktest-688c687f98-rdxb2 tmux
```

spark-submit

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
datastore-elasticsearch-headless 9200 - - 9 true false true planes 60s 10000 0 false
```

The Spark Job should start.  You can verify using ```kubectl get pods```.  You should see a driver and in this case 9 exec.


#### Verify Pod Placement

kubectl get pods -o wide

The pods should be running on nodes per label assignment.  

#### Elastic Index Mon (EIM)

```
kubectl exec -it rttest-send-0 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-headless:9200/planes 60 3
```

#### KafkaTopicMon (KTM)

```
kubectl exec -it rttest-send-0 tmux
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes9
```

#### Send Kafka

```
kubectl exec -it rttest-send-0 tmux
cd /opt/rttest
bash sendPlanes gateway-cp-kafka:9092 planes9 planes00000 200 40 2
```


#### Test Results

KTM: 400k/s


|Query Number|Sample Number|Epoch (ms)    |Time (s) |Count             |Linear Reg. Rate  |Rate From Previous|Rate From First   |
|------------|-------------|--------------|---------|------------------|------------------|------------------|------------------|
|          1 |           1 |1557245130377 |       0 |           59,870 |                  |                  |                  |
|          2 |           2 |1557245190262 |      59 |          108,864 |              818 |              818 |              818 |
|          3 |           3 |1557245250389 |     120 |          700,028 |            5,337 |            9,832 |            5,334 |
|          4 |           4 |1557245310261 |     179 |        1,373,431 |            7,556 |           11,247 |            7,302 |
|          5 |           5 |1557245370316 |     239 |        2,019,879 |            8,643 |           10,764 |            8,169 |
|          6 |           6 |1557245430264 |     299 |        2,368,137 |            8,549 |            5,809 |            7,697 |
|          7 |           7 |1557245490265 |     359 |        2,647,964 |            8,099 |            4,664 |            7,191 |
|          8 |           8 |1557245550265 |     419 |        3,287,404 |            8,125 |           10,657 |            7,687 |
|          8 |           8 |1557245550265 |     419 |        3,287,404 |            8,125 |           10,657 |            7,687 |
|          9 |           9 |1557245610439 |     480 |        3,949,988 |            8,330 |           11,011 |            8,103 |
|         10 |          10 |1557245670444 |     540 |        4,578,323 |            8,551 |           10,471 |            8,366 |
|         11 |          11 |1557245730280 |     599 |        4,650,724 |            8,339 |            1,210 |            7,653 |
|         12 |          12 |1557245790335 |     659 |        5,187,335 |            8,239 |            8,935 |            7,769 |
|         13 |          13 |1557245850336 |     719 |        5,815,221 |            8,253 |           10,465 |            7,994 |
|         14 |          14 |1557245910315 |     779 |        6,490,519 |            8,347 |           11,259 |            8,245 |
|         15 |          15 |1557245970355 |     839 |        6,922,815 |            8,379 |            7,200 |            8,170 |
|         16 |          16 |1557246030306 |     899 |        7,141,350 |            8,297 |            3,645 |            7,869 |
|         17 |          17 |1557246090263 |     959 |        7,822,865 |            8,300 |           11,367 |            8,087 |
|         18 |          18 |1557246150265 |    1019 |        8,472,425 |            8,347 |           10,826 |            8,249 |
|         19 |          19 |1557246210421 |    1080 |        9,080,460 |            8,408 |           10,108 |            8,352 |
|         20 |          20 |1557246270358 |    1139 |        9,363,915 |            8,401 |            4,729 |            8,162 |
|         21 |          21 |1557246330268 |    1199 |        9,728,404 |            8,365 |            6,084 |            8,058 |
|         22 |          22 |1557246390264 |    1259 |       10,401,396 |            8,372 |           11,217 |            8,208 |
|         23 |          23 |1557246450267 |    1319 |       11,046,357 |            8,403 |           10,749 |            8,324 |
|         24 |          24 |1557246510414 |    1380 |       11,625,034 |            8,439 |            9,621 |            8,380 |
|         25 |          25 |1557246570413 |    1440 |       11,699,575 |            8,401 |            1,242 |            8,083 |
|         26 |          26 |1557246630263 |    1499 |       12,288,832 |            8,383 |            9,846 |            8,153 |
|         27 |          27 |1557246690264 |    1559 |       12,680,334 |            8,354 |            6,525 |            8,091 |
|         28 |          28 |1557246750409 |    1620 |       13,013,050 |            8,310 |            5,532 |            7,996 |
|         29 |          29 |1557246810378 |    1680 |       13,641,192 |            8,289 |           10,474 |            8,084 |
|         30 |          30 |1557246870264 |    1739 |       14,079,329 |            8,266 |            7,316 |            8,058 |
|         31 |          31 |1557246930313 |    1799 |       14,302,312 |            8,220 |            3,713 |            7,913 |
|         32 |          32 |1557246990442 |    1860 |       14,971,054 |            8,198 |           11,122 |            8,016 |
|         33 |          33 |1557247050263 |    1919 |       15,642,570 |            8,196 |           11,225 |            8,116 |
|         34 |          34 |1557247110264 |    1979 |       16,334,384 |            8,212 |           11,530 |            8,220 |
|         35 |       ***** |1557247170264 |    2039 |       16,334,384 |            8,212 |                0 |            7,978 |
|         36 |          35 |1557247230263 |    2099 |       16,994,875 |            8,198 |            5,504 |            8,065 |
|         37 |          36 |1557247290351 |    2159 |       17,554,818 |            8,192 |            9,319 |            8,100 |
|         38 |          37 |1557247350382 |    2220 |       17,790,391 |            8,168 |            3,924 |            7,987 |


Rate is around 8k/s

Much slower ingest rates on k8s.  On VM's rates were 55k/s on k8s 8k/s.

Checked cpu/mem usage (kubectl top nodes); less than 10% of cpu and 50% of mem in use.

Tried setting: vm.max_map_count=262144 on the es node; no notable improvement.




















