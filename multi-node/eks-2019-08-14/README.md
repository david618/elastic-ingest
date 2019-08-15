### Setup EKS 25 Nodes using kubernetes 1.13

Using [eksctl](https://eksctl.io/)

Used brew to upgrade my eksctl.  The older version did not support creating 1.13.

```
eksctl create cluster \
--name dj0814 \
--region us-east-2 \
--version 1.13 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 25 \
--nodes-min 25 \
--nodes-max 25 \
--node-ami auto \
--ssh-public-key centos
```

This creates a 25 node cluster using m5.4xlarge (16 cores/64GB mem) and EKS enabled.


#### Add Taints and Labels

```
kubectl taint nodes ip-192-168-87-23.us-east-2.compute.internal key=test:NoSchedule
kubectl taint nodes ip-192-168-90-214.us-east-2.compute.internal key=test:NoSchedule
kubectl taint nodes ip-192-168-94-195.us-east-2.compute.internal key=test:NoSchedule

kubectl label nodes ip-192-168-87-23.us-east-2.compute.internal func=test
kubectl label nodes ip-192-168-90-214.us-east-2.compute.internal func=test
kubectl label nodes ip-192-168-94-195.us-east-2.compute.internal func=test
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


#### Add Drives

Manually Created 14 Volumes
- 1024GB each
- 5 in zone-a
- 5 in zone-b
- 4 in zone-c

Attached the disks to Instances.  Each to separate instance in the corresponding zones.


#### Install Portworx

https://install.portworx.com/

```
kubectl version --short | awk -Fv '/Server Version: / {print $3}'
1.13.8-eks-a977ba
```

- ETCD: Build-in
- Cloud: Consume Unused; Skip KVDB
- Network: auto / auto
- EKS

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.13.8-eks-a977ba&b=true&c=px-cluster-0f9d395a-e5c3-408a-96ff-8abd966c403b&eks=true&stork=true&lh=true&st=k8s'
```

Wait for pods to start.

```
kubectl -n kube-system get pods
```

```
kubectl -n kube-system exec portworx-m24nx -- /opt/pwx/bin/pxctl status
```

Showed 13TB Capacity.   This was because I applied label/taint to one of the nodes which I added px drive.  


Create Storage Classes

```
kubectl apply -f ../portworx-storageclasses.yaml
```

#### Reinstall Portworx using Cloud Drives

```
curl -fsL https://install.portworx.com/px-wipe  |  bash
```

Once completed; umount all the drives attached in previous step and delete them.


Add IAM Role
- Roles
- Search (e.g. dj0814); Select the NodeInstanceRole
- Add Inline policy
- Select JSON Tab
- Paste in Following

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "<stmt-id>",
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


- Change ``<stmt-id>`` to something you like (e.g. dj0814)
- Click Review Policy
- Give The Policy a Name (e.g. px-cloud-drive)

### Limit Portworx Cloud Drives to Specific Nodes

#### Label All False

```
kubectl label nodes --all px/enabled=false --overwrite
```

#### Enable First 14 Nodes

```
for node in $(kubectl get nodes -o name | head -n 14); do 
  echo $node
  kubectl label  $node px/enabled=true --overwrite 
done
```

```
 kubectl get nodes --show-labels | grep 'px/enabled=true' | wc -l
```

From https://install.portworx.com/

- Version: 1.13.8-eks-a977ba
- ETCD: Built-in
- Cloud; AWS
- Create Using a Spec
- GP2: 1024
- Defaults for Metadata Device
- EKS

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.13.8-eks-a977ba&b=true&s=%22type%3Dgp2%2Csize%3D1024%22&md=type%3Dgp2%2Csize%3D150&c=px-cluster-68fba5fc-57fa-469d-b181-36f172693834&eks=true&stork=true&lh=true&st=k8s'
```


#### Install Elasticsearch 


Set schedulerName "stork" and storageClassName to "px-db-rf3-dbr-sc"

From aks/azcli folder of repo.

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```

```
kubectl edit sts datastore-elasticsearch-client
```

Changed replicas from 2 to 10.

#### Install Gateway 

Set schedulerName "stork" and storageClassName to "px-db-rf3-dbr-sc"

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

#### Run Tests


From aks/manifests folder.

```
bash run-test-10part-600k.sh > dj0813-gp2-08141020.log &
```

Collect results. 


```
kubectl logs $(kubectl get pod -l app=rttest-mon-es -o name) -f
```

The log file output's the logs for es and kafka mon.  From Elasticsearch Logs use the "Rate from First" value that is second from last.  The last line will be inaccurate; because the sample was taken after the send had terminated.  




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
- Scale Datastore (2 to 10)
- Install Gateway 
- Start Test



#### Additional Test Runs

```
bash run-test-10part-600k.sh > dj0814-px1-08141348.log &
bash run-test-10part-repl2.sh > dj0814-repl2-08141658.log &
bash run-test-10part-repl3.sh > dj0814-repl3-08142018.log &
```


#### Results


Ran 12 interations of each test.

- gp2    : Google's default Storage Class
- px1    : Portworx Replication Factor 2 with io-profile set to db_remote
- gp2-r2 : Google's default Storage Class; Elasticsearch and Kafka set to Repl 2
- gp2-r3 : Google's default Storage Class; Elasticsearch and Kafka set to Repl 2
 

|Test Case|Average|Standard Deviation|
|---------|-------|------------------|
|gp2      |543    |3                 |
|px1      |523    |18                |
|gp2-r2   |403    |3                 |
|gp2-r3   |274    |6                 |


#### Delete

```
eksctl get cluster -r us-east-2
NAME	REGION
dj0814	us-east-2
```

```
eksctl delete cluster dj0814 -r us-east-2
```

**NOTE**: Delete failed. Tried to Delete from AWS Console failed again.  The error pointed to the IAM Role created during Portworx Cloud Drive install.  Deleted the IAM Role created above; then delete worked.



