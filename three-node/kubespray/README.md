### kubespray

#### Create RG

```
az group create -l westus2 -n dj0610d
```

#### Clone kubespray

```
git clone https://github.com/kubernetes-sigs/kubespray
```

Docs at https://kubespray.io

#### Create Nodes

In ``contrib/azurerm``

vi group_vars/all
- cluster_name:  dj0610d
- number_of_k8s_nodes: 9
- masters_vm_size: Standard_D4s_v3
- minions_vm_size: Standard_D16s_v3
- admin_username: david
- admin_password: Some complicated password
- ssh_public_keys: Replace with your public key
- azure_storage_account_type: Premium_LRS



```
bash apply-rg.sh dj0610d
```

This will create the VM's, Network, etc. on Azure.  Took about 6 minutes.

Assumes you have az cli installed and you have logged in.

#### Installing Requirements on Ubuntu 18.04

**Optional:** This is only required if installing Ubuntu 18.04

From my MAC centos install worked; however, install on Ubuntu 18.04 failed with error messages about yum, dnf, and dbus.

Install worked if ran from master-0 (running Ubuntu 18.04).

```
sudo -y apt-get install python-pip
```

```
sudo pip install -r requirements.txt
```



#### Create Inventory

```
./generate-inventory.sh dj0610d
```

#### Create Copy of Sample

```
cp -rf inventory/sample/ inventory/dj0610d
```

#### Copy Inventory File

```
cp contrib/azurerm/inventory inventory/dj0610d/
```

#### Edit Files in Copy

```
vi inventory/dj0610d/group_vars/all/azure.yml
```

Set values; the [Azure docs page](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/azure.md) provides instructions on how to find the parameters. 

```
azure_tenant_id: *******************************
azure_subscription_id: **********************************
azure_aad_client_id: *********************************
azure_aad_client_secret: *******************************
azure_resource_group: dj0610d
azure_location: westus2
azure_subnet_name: agent
azure_security_group_name: dj0610d_agent
azure_vnet_name: dj0610d
azure_vnet_resource_group: dj0610d
azure_route_table_name: dj0610d
azure_loadbalancer_sku: standard
```

```
vi inventory/dj0610d/group_vars/k8s-cluster/k8s-cluster.yml
```

- calico is not supported on Azure.   
- flannel/CentOS worked; that's what I used for first test.
- cilium/Ubuntu: Install failed; stop if Kernel Version is too low.  (Kernel Version is 3.10)
- cloud/Ubnutu failed; could not curl using DNS name from rttest to Elasticsearch
- contiv/Ubuntu

Using Ubuntu 18.04; cilium driver installed.  Install was done from master-0.  


Made a change to config and reran ansible playbook to deploy.


```
vi inventory/dj0610d/group_vars/all/all.yaml
```

Uncomment and set
cloud: azure

#### Install Kubernetes 

```
ansible-playbook -i inventory/dj0610d/inventory -u david --become cluster.yml
```

#### Secure Shell to Master


#### Configure Kubectl

Copied from root .kube/config to david


#### Install Portworx

Added disk to each of the minions (1TB)


##### Generate Portwrox Config

Using https://install.portworx.com/

```
kubectl version --short | awk -Fv '/Server Version: / {print $3}'
```

1.14.3

OnPrem; Automatically scan disks
Skip KVDB

Are you running on either of these?  None

##### Apply Configuration

CentOS 7.5

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.14.1&b=true&c=px-cluster-0c823351-4d3c-4bba-968e-66e897e3dcb4&stork=true&lh=true&st=k8s'
```

Ubuntu 18.04

```
kubectl apply -f 'https://install.portworx.com/?mc=false&kbver=1.14.3&b=true&c=px-cluster-8dd98fe9-f80c-433c-ab00-9e56fe801122&stork=true&lh=true&st=k8s'
```

#### Install Helm 

https://helm.sh/docs/using_helm/#installing-helm

curl -O https://get.helm.sh/helm-v2.14.0-linux-amd64.tar.gz
tar xvzf helm-v2.14.0-linux-amd64.tar.gz
cd linux-amd64/

sudo cp helm /usr/local/bin/

helm init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

#### Clone Installers (A4IOT)

```
sudo yum -y install epel-release
sudo yum -y install git

git clone https://github.com/ArcGIS/trinity-operations


#### Create Storage Classes for Portworx

cd trinity-operations/devops/install

kubectl apply -f portworx-storageclasses.yaml


#### Install Datastore

Modified es stores/datastore/es-master-values.yaml; took secure out of storageClassName  px-db-rf3-sc

cd azcli

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-master-values.yaml datastore-elasticsearch-master ../helm-charts/elastic/elasticsearch
```

```
helm upgrade --wait --timeout=600 --install --values ../stores/datastore/es-client-values.yaml datastore-elasticsearch-client ../helm-charts/elastic/elasticsearch
```

kubectl get pods should show the datastore deployed and kubectl get pvc will show Portworx volumes

#### Install Gateway

vi ../cp-helm-charts/values-prod.yaml   Take secure off storageClassName.

```
helm upgrade --wait --timeout=600 --install --values ../cp-helm-charts/values-prod.yaml gateway ../cp-helm-charts
```

#### Install SparkOperator

```
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm install incubator/sparkoperator --namespace spark-operator --set enableWebhook=true

kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

#### Clone elastic-ingest

```
git clone https://github.com/david618/elastic-ingest
```

#### Deploy rttest-mon

```
kubectl  apply -f rttest-mon.yaml
```

#### Create Kafka Topic

```
kubectl exec -it gateway-cp-kafka-0 --container cp-kafka-broker bash
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes3 --create --replication-factor 1 --partitions 3
kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic planes5 --create --replication-factor 1 --partitions 5

```

#### Create Spark Job

```
kubectl apply -f sparkop-es-2.4.1.yaml
```

Configure for planes3; 6 executors; 4 cpu and 5G mem for each executor

#### Start ElasticIndexMon (EIM)

```
kubectl exec -it rttest-mon-2 tmux
```

```
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://datastore-elasticsearch-client:9200/planes 10 8
```

#### Start KafkaTopicMon (KTM)

```
kubectl exec -it rttest-mon-1 tmux
```

```
cd /opt/rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon gateway-cp-kafka:9092 planes3
```

#### Start Send

Edited rttest-send-kafka-25k-5m sending planes3.

Eight instances at 25k/s sending at 200k/s

```
kubectl apply -f rttest-send-kafka-25k-5m.yaml
```

Deployment configured to use eight instances; expected total rate is 200k/s, sending 40 million total messages.

To restart: kubectl delete pod -l app=rttest-send-kafka-25k-5m


**Note:** First run there is a delay as the docker image rrtest is downloaded from docker hub.



#### Results

Using default 2 node datastore (each node 14 cpu/50G mem/26G heap)

Average Ingest Rate EIM: 93k/s

Using 3 node datastore; average ingest rate EIM: 103k/s

Using 5 node datastore; average ingest rate EIM: 119k/s

#### Observations

Based on this test k8s installed with Kubespary on Azure VM's demonstrates same performances issue as AKS.



