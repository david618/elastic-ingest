### Setup EKS 6 Nodes using kubernetes 1.13

Using [eksctl](https://eksctl.io/)

Used brew to upgrade my eksctl.  The older version did not support creating 1.13.

```
eksctl create cluster \
--name dj0815 \
--region us-east-2 \
--version 1.13 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 6 \
--nodes-min 6 \
--nodes-max 6 \
--node-ami auto \
--ssh-public-key centos
```

This creates a 6 node cluster using m5.4xlarge (16 cores/64GB mem) and EKS enabled.


#### Get kubeconfig File

If needed you can get kubeconfig file using eksctl


```
eksctl utils write-kubeconfig --name=dj0815 -r us-east-2   
```

#### Add Taints and Labels

```
kubectl taint nodes ip-192-168-89-189.us-east-2.compute.internal key=test:NoSchedule
kubectl label nodes ip-192-168-89-189.us-east-2.compute.internal func=test
```


#### Install Dashboard

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/heapster.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/influxdb/influxdb.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
```

#### Set Service Account Permissions

```
kubectl apply -f eks-admin.yaml
```

#### Install Helm

```
helm  init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```

#### Install Portworx using Cloud Drives

- From AWS Console navigate to IAM
- Select Roles
- In Search under Create Role search for Cluster (e.g. dj0815)
- Select the nodegroup (e.g. eksctl-dj0815-nodegroup-standard-NodeInstanceRole)
- Click Add Inline Policy
- Select JSON Tab and Paste Following

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:DetachVolume",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteTags",
                "ec2:DeleteVolume",
                "ec2:DescribeTags",
                "ec2:DescribeVolumeAttribute",
                "ec2:DescribeVolumesModifications",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:DescribeInstances"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

- Click Review Policy
- Give The Policy a Name (e.g. px-cloud-drive); Click Create Policy


From https://install.portworx.com/

- Version: 1.13.8-eks-a977ba
- ETCD: Built-in
- Cloud; AWS
- Create Using a Spec
- GP2: 1024
- Defaults for Metadata Device
- EKS

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.13.8-eks-a977ba&b=true&s=%22type%3Dgp2%2Csize%3D1024%22&md=type%3Dgp2%2Csize%3D150&c=px-cluster-264e4be9-086b-4c93-b212-36ea240e3aac&eks=true&stork=true&lh=true&st=k8s'
```

After a few minutes.

```
kubectl -n kube-system exec $(kubectl -n kube-system get pods -l name=portworx -o name | cut -d'/' -f 2 | head -n 1) -- /opt/pwx/bin/pxctl status
```

Shows 5TB.

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
bash run-test-10part.sh > dj0815-gp2-08150925.log &
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
bash run-test-10part.sh > dj815-px-rf3-dbr-08161645.log &
```


#### Results


Ran 12 interations of each test.

- gp2: EKS gpt Storage Class (no Portworx)
- gp2-rf2: EKS gpt (Kafka/Elasticsearch Replication Factor 2)
- gp2-px1: EKS Portworx Replication Factor 1
- gp2-px2: EKS Portworx Replication Factor 2
- gp2-px3: EKS Portworx Replication Factor 3
- gp2-px2-dbr: EKS Portworx Replication Factor 2; io_profile=db_remote
- gp2-px3-dbr: EKS Portworx Replication Factor 3; io_profile=db_remote


|Test Case   |Average|Standard Deviation|
|------------|-------|------------------|
|gp2         |132    |3.0               |
|gp2-rf2     |68     |2.0               |
|gp2-px1     |127    |3.9               |
|gp2-px2     |124    |1.9               |
|gp2-px3     |106    |3.8               |
|gp2-px2-dbr |130     |3.0               |
|gp2-px3-dbr |114     |2.8               |


#### Delete

Remove Role from IAM added for portworx.

```
eksctl get cluster -r us-east-2
NAME	REGION
dj0815	us-east-2
```

```
eksctl delete cluster dj0815 -r us-east-2
```




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
bash run-test-10part.sh > dj815-px-rf3-dbr-08161645.log &
```


#### Results


Ran 12 interations of each test.

- gp2: EKS gpt Storage Class (no Portworx)
- gp2-rf2: EKS gpt (Kafka/Elasticsearch Replication Factor 2)
- gp2-px1: EKS Portworx Replication Factor 1
- gp2-px2: EKS Portworx Replication Factor 2
- gp2-px3: EKS Portworx Replication Factor 3
- gp2-px2-dbr: EKS Portworx Replication Factor 2; io_profile=db_remote
- gp2-px3-dbr: EKS Portworx Replication Factor 3; io_profile=db_remote


|Test Case   |Average|Standard Deviation|
|------------|-------|------------------|
|gp2         |132    |3.0               |
|gp2-rf2     |68     |2.0               |
|gp2-px1     |127    |3.9               |
|gp2-px2     |124    |1.9               |
|gp2-px3     |106    |3.8               |
|gp2-px2-dbr |130     |3.0               |
|gp2-px3-dbr |114     |2.8               |


#### Delete

Remove Role from IAM added for portworx.

```
eksctl get cluster -r us-east-2
NAME	REGION
dj0815	us-east-2
```

```
eksctl delete cluster dj0815 -r us-east-2
```
