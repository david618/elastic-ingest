

## Sparkop without ACI

```
apiVersion: "sparkoperator.k8s.io/v1beta1"
kind: SparkApplication
metadata:
  name: sparkpi-op
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: "gcr.io/spark-operator/spark:v2.4.0"
  imagePullPolicy: Always
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.11-2.4.0.jar"
  sparkVersion: "2.4.0"
  restartPolicy:
    type: Never
  driver:
    cores: 0.1
    coreLimit: "200m"
    memory: "512m"
    labels:
      version: 2.4.0
    serviceAccount: spark
  executor:
    cores: 1
    instances: 1
    memory: "512m"
    labels:
      version: 2.4.0
```

```
kubectl apply -f sparkpi-op.yaml
```

Driver and exec start.

```
sparkpi-op-1562691454794-exec-1             1/1     Running     0          6s
sparkpi-op-driver                           1/1     Running     0          59s
```

```
kubectl logs sparkpi-op-driver
```

Shows expected output: ```Pi is roughly 3.135075675378377```


### Sparkop with ACI


```
apiVersion: "sparkoperator.k8s.io/v1beta1"
kind: SparkApplication
metadata:
  name: sparkpi-op-aci
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: "gcr.io/spark-operator/spark:v2.4.0"
  imagePullPolicy: Always
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.11-2.4.0.jar"
  sparkVersion: "2.4.0"
  restartPolicy:
    type: Never
  nodeSelector:
    kubernetes.io/role: agent
    beta.kubernetes.io/os: linux
    type: virtual-kubelet
  driver:
    cores: 0.1
    coreLimit: "200m"
    memory: "512m"
    labels:
      version: 2.4.0
    serviceAccount: spark
    tolerations:
    - key: virtual-kubelet.io/provider
      operator: Exists
    - key: azure.com/aci
      effect: NoSchedule
  executor:
    cores: 1
    instances: 1
    memory: "512m"
    labels:
      version: 2.4.0
    tolerations:
    - key: virtual-kubelet.io/provider
      operator: Exists
    - key: azure.com/aci
```

```
kubectl apply -f sparkpi-op-aci.yaml
```

```
sparkpi-op-aci-driver                       0/1     NotFound    0          70s
```

```
kubectl describe pod sparkpi-op-aci-driver

  Normal  Scheduled  101s  default-scheduler  Successfully assigned default/sparkpi-op-aci-driver to virtual-node-aci-linux
```

```
kubectl logs sparkpi-op-aci-driver
Error from server (InternalError): Internal error occurred: error getting container logs?): api call to https://management.azure.com/subscriptions/42e12bff-9125-4a9a-987d-685e9c480b0a/resourceGroups/MC_dj0709a_dj0709a-cluster_westus2/providers/Microsoft.ContainerInstance/containerGroups/default-sparkpi-op-aci-driver?api-version=2018-10-01: got HTTP response status code 404 error code "ResourceNotFound": The Resource 'Microsoft.ContainerInstance/containerGroups/default-sparkpi-op-aci-driver' under resource group 'MC_dj0709a_dj0709a-cluster_westus2' was not found.
```

