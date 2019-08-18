### Setup AKS 6 Nodes using kubernetes 1.13

```
bash install-aks-13.sh dj0815a westus2 16 6
```

#### Add Taints and Labels

```
kubectl taint nodes aks-nodepool1-86189965-5 key=test:NoSchedule
kubectl label nodes aks-nodepool1-86189965-5 func=test
```

### Install Portworx

```
bash install-portworx-15.sh dj0815a 1024 yes
```

The install will timeout and fail; because of taint.  That's ok.


```
kubectl -n kube-system exec $(kubectl -n kube-system get pods -l name=portworx -o name | cut -d'/' -f 2 | head -n 1) -- /opt/pwx/bin/pxctl status
```

Shows 5TB.


#### Install Elasticsearch 


Comment out schedulerName "stork" and storageClassName to "managed-premium"

For Brokers:
- Resource requests and limit for Kafka Broker: 5 cpu 
- Resource requests 18Gi memory
- heapOptions "-Xms9G -Xmx9G"

From aks/azcli folder of repo.

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```


#### Install Gateway 

Comment out schedulerName "stork" and storageClassName to "managed-premium"

Set Resource request for Kafka Broker: 7 cpu and 26Gi memory; Set heapOptions "-Xms13G -Xmx13G"

Set number of brokers to 2.

```
helm upgrade --wait --timeout=600 --install --values ../helm-charts/confluent/values-prod.yaml gateway ../helm-charts/confluent
```

#### Install Spark Operator

```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm install incubator/sparkoperator --name spark --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

#### Install Elasticsearch 


Comment out schedulerName "stork" and storageClassName to "gp2"

Set Resource request for Kafka Broker: 7 cpu and 26Gi memory; Set heapOptions "-Xms13G -Xmx13G" for data nodes (es-client-values).


From aks/azcli folder of repo.

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch

```


#### Install Gateway 

Comment out schedulerName "stork" and storageClassName to "gp2"

For Brokers:
- Resource requests and limit for Kafka Broker: 5 cpu 
- Resource requests 18Gi memory
- heapOptions "-Xms9G -Xmx9G"

**Note:** Tried to set broker's to two; however, cp-kafka-connect expects 3 and would require adjustments to run on 2.

```
helm upgrade --wait --timeout=600 --install --values ../helm-charts/confluent/values-prod.yaml gateway ../helm-charts/confluent
```

#### Install Spark Operator

```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm install incubator/sparkoperator --name spark --namespace spark-operator --set enableWebhook=true
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

### Sparkop Job

```
vi sparkop-es-2.4.1-10part.yaml
```

Set number of executor instances to 10 instead of 20.  

#### Run Tests


From aks/manifests folder.

```
bash run-test-10part.sh > dj08151-azmp-08150925.log &
```

Collect results. 


#### Reset for Another Test

##### Remove Test Apps
```
kubectl delete -f sparkop-es-2.4.1-10part.yaml
kubectl delete -f rttest-send-kafka-25k-10m-10part.yaml
kubectl delete -f rttest-mon-es-tol.yaml
kubectl delete -f rttest-mon-kafka-tol.yaml

```

##### Remove Datastore

```
helm delete --purge datastore-elasticsearch-client
helm delete --purge datastore-elasticsearch-master
kubectl delete pvc -l app=datastore-elasticsearch-client
kubectl delete pvc -l app=datastore-elasticsearch-master

```

##### Remove Gateway

```
helm delete --purge gateway
kubectl delete pvc -l app=cp-kafka
kubectl delete pvc -l app=cp-zookeeper

```

#### Edit Configs

Edit values (e.g. Change to px-db-rf2-dbr-sc)

```
vi ../helm-charts/confluent/values-prod.yaml
vi ../stores/datastore/es-client-values.yaml
vi ../stores/datastore/es-master-values.yaml
```

#### Reinstall and Start Test

- Install Datastore
- Install Gateway 
- Start Test



#### Additional Test Runs

```
bash run-test-10part.sh > dj815-azmp-px2-dbr-08161645.log &
```


#### Results


Ran 12 interations of each test.


- azmp: Azure Managed Premium (no Portworx)
- azmp-rf2: Azure Managed Premium (Kafka/Elasticsearch Replication Factor 2)
- azmp-px1: AKS Portworx Replication Factor 1
- azmp-px2: AKS Portworx Replication Factor 2
- azmp-px3: AKS Portworx Replication Factor 3
- azmp-px2-dbr: AKS Portworx Replication Factor 2; io_profile=db_remote
- azmp-px3-dbr: AKS Portworx Replication Factor 3; io_profile=db_remote


|Test Case   |Average|Standard Deviation|
|------------|-------|------------------|
|azmp        |95     |2.2               |
|azmp-rf2    |48     |1.5               |
|azmp-px1    |99     |1.5               |
|azmp-px2    |83     |2.5               |
|azmp-px3    |68     |1.2               |
|azmp-px2-dbr|97     |2.0               |
|azmp-px3-dbr|77     |1.5               |


#### Delete

Remove Role from IAM added for portworx.

```
./delete_tenant.sh dj0815a
```

