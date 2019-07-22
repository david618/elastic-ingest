
## Running SparkPi on ACI

### Build Spark Docker

```
curl -O https://archive.apache.org/dist/spark/spark-2.4.3/spark-2.4.3-bin-hadoop2.7.tgz
```

```
tar xvzf spark-2.4.3-bin-hadoop2.7.tgz
```

```
cd spark-2.4.3-bin-hadoop2.7
```

```
sudo docker build -t david62243/spark:2.4.3 -f kubernetes/dockerfiles/spark/Dockerfile  .
```

```
sudo docker login
sudo docker push david62243/spark:2.4.3
```

### Create Default Service Account RBAC

**Note:** This may not be the best security practice.

[default-service-account-rbac.yaml](../../install/aks/manifests/default-service-account-rbac.yaml)

```
kubectl apply -f default-service-account-rbac.yaml
```

Without you'll get an error when executing Spark jobs.  

```
forbidden: User "system:serviceaccount:default:default" cannot watch resource "pods" in API group "" in the namespace "default"
```


### Create Pod

```
apiVersion: v1
kind: Pod
metadata:
  name: david62243-spark
  namespace: default
spec:
  containers:
  - name: david62243-spark
    image: david62243/spark:2.4.3
    command:
    - sh
    - -c
    - "exec tail -f /dev/null"
```

```
kubectl apply -f david62243-spark.yaml
```

### Exec into Pod; Run Spark Pi

```
kubectl exec -it david62243-spark -- /bin/ash
```


```
/opt/spark/bin/spark-submit \
  --master k8s://https://kubernetes:443 \
  --deploy-mode cluster \
  --name spark-pi \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=david62243/spark:2.4.3 \
  local:///opt/spark/examples/jars/spark-examples_2.11-2.4.3.jar
```

### Status 


```
kubectl get pods
```

You should see driver and three exec start.  When done driver will have status "Completed"

```
kubectl logs spark-pi-1562685801113-driver
```

You should see a line like: ``Pi is roughly 3.1509757548787745``

### Create Driver on ACI


```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: david62243-spark-aci
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: david62243-spark-aci
  template:
    metadata:
      labels:
        app: david62243-spark-aci
    spec:
      containers:
      - name: david62243-spark-aci
        image: david62243/spark:2.4.3
        command:
        - sh
        - -c
        - "exec tail -f /dev/null"
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
      - key: azure.com/aci
        effect: NoSchedule
```

```
kubectl apply -f david62243-spark-aci.yaml
```

From get pods -w the pod is deployed to aci instance.

Took about 3 minutes for pod to start.

```
kubectl exec -it david62243-spark-aci-6549499765-n464z -- /bin/ash
```

```
/opt/spark/bin/spark-submit \
  --master k8s://https://kubernetes:443 \
  --deploy-mode cluster \
  --name spark-pi \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=david62243/spark:2.4.3 \
  local:///opt/spark/examples/jars/spark-examples_2.11-2.4.3.jar
```

This failed with error

```
Task@690bf4e1 rejected from java.util.concurrent.ScheduledThreadPoolExecutor@7c42707[Terminated, pool size = 0, active threads = 0, queued tasks = 0, completed tasks = 0]
	at java.util.concurrent.ThreadPoolExecutor$AbortPolicy.rejectedExecution(ThreadPoolExecutor.java:2063)
	at java.util.concurrent.ThreadPoolExecutor.reject(ThreadPoolExecutor.java:830)
	at java.util.concurrent.ScheduledThreadPoolExecutor.delayedExecute(ScheduledThreadPoolExecutor.java:326)
	at java.util.concurrent.ScheduledThreadPoolExecutor.schedule(ScheduledThreadPoolExecutor.java:533)
	at java.util.concurrent.ScheduledThreadPoolExecutor.submit(ScheduledThreadPoolExecutor.java:632)
	at java.util.concurrent.Executors$DelegatedExecutorService.submit(Executors.java:678)
	at io.fabric8.kubernetes.client.dsl.internal.WatchConnectionManager.scheduleReconnect(WatchConnectionManager.java:303)
	at io.fabric8.kubernetes.client.dsl.internal.WatchConnectionManager.access$800(WatchConnectionManager.java:48)
	at io.fabric8.kubernetes.client.dsl.internal.WatchConnectionManager$2.onFailure(WatchConnectionManager.java:216)
	at okhttp3.internal.ws.RealWebSocket.failWebSocket(RealWebSocket.java:543)
	at okhttp3.internal.ws.RealWebSocket$2.onFailure(RealWebSocket.java:208)
	at okhttp3.RealCall$AsyncCall.execute(RealCall.java:148)
	at okhttp3.internal.NamedRunnable.run(NamedRunnable.java:32)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:748)
io.fabric8.kubernetes.client.KubernetesClientException: Failed to start websocket
	at io.fabric8.kubernetes.client.dsl.internal.WatchConnectionManager$2.onFailure(WatchConnectionManager.java:207)
	at okhttp3.internal.ws.RealWebSocket.failWebSocket(RealWebSocket.java:543)
	at okhttp3.internal.ws.RealWebSocket$2.onFailure(RealWebSocket.java:208)
	at okhttp3.RealCall$AsyncCall.execute(RealCall.java:148)
	at okhttp3.internal.NamedRunnable.run(NamedRunnable.java:32)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.lang.Thread.run(Thread.java:748)
Caused by: java.net.UnknownHostException: kubernetes: Name does not resolve
	at java.net.Inet6AddressImpl.lookupAllHostAddr(Native Method)
	at java.net.InetAddress$2.lookupAllHostAddr(InetAddress.java:929)
	at java.net.InetAddress.getAddressesFromNameService(InetAddress.java:1324)
	at java.net.InetAddress.getAllByName0(InetAddress.java:1277)
	at java.net.InetAddress.getAllByName(InetAddress.java:1193)
	at java.net.InetAddress.getAllByName(InetAddress.java:1127)
	at okhttp3.Dns$1.lookup(Dns.java:39)
	at okhttp3.internal.connection.RouteSelector.resetNextInetSocketAddress(RouteSelector.java:171)
	at okhttp3.internal.connection.RouteSelector.nextProxy(RouteSelector.java:137)
	at okhttp3.internal.connection.RouteSelector.next(RouteSelector.java:82)
	at okhttp3.internal.connection.StreamAllocation.findConnection(StreamAllocation.java:171)
	at okhttp3.internal.connection.StreamAllocation.findHealthyConnection(StreamAllocation.java:121)
	at okhttp3.internal.connection.StreamAllocation.newStream(StreamAllocation.java:100)
	at okhttp3.internal.connection.ConnectInterceptor.intercept(ConnectInterceptor.java:42)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:67)
	at okhttp3.internal.cache.CacheInterceptor.intercept(CacheInterceptor.java:93)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:67)
	at okhttp3.internal.http.BridgeInterceptor.intercept(BridgeInterceptor.java:93)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RetryAndFollowUpInterceptor.intercept(RetryAndFollowUpInterceptor.java:120)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:67)
	at io.fabric8.kubernetes.client.utils.BackwardsCompatibilityInterceptor.intercept(BackwardsCompatibilityInterceptor.java:119)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:67)
	at io.fabric8.kubernetes.client.utils.ImpersonatorInterceptor.intercept(ImpersonatorInterceptor.java:68)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:67)
	at io.fabric8.kubernetes.client.utils.HttpClientUtils$2.intercept(HttpClientUtils.java:107)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:92)
	at okhttp3.internal.http.RealInterceptorChain.proceed(RealInterceptorChain.java:67)
	at okhttp3.RealCall.getResponseWithInterceptorChain(RealCall.java:185)
	at okhttp3.RealCall$AsyncCall.execute(RealCall.java:135)
	... 4 more
19/07/09 15:37:32 INFO ShutdownHookManager: Shutdown hook called
19/07/09 15:37:32 INFO ShutdownHookManager: Deleting directory /tmp/spark-d6230369-21f5-4926-a13f-eb8024d52019
```

#### Tried using IP instead for k8s


```
/opt/spark/bin/spark-submit \
  --master k8s://https://10.0.0.1:443 \
  --deploy-mode cluster \
  --name spark-pi \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=david62243/spark:2.4.3 \
  local:///opt/spark/examples/jars/spark-examples_2.11-2.4.3.jar
```

This worked.

#### Looking at resolve.con

The ACI Pods cannot access services.

cat /etc/resolv.conf
nameserver 10.0.0.10

vs.

cat /etc/resolv.conf
nameserver 10.0.0.10
search default.svc.cluster.local svc.cluster.local cluster.local qvecqzdgkdkedllj5mh4iaxb1f.xx.internal.cloudapp.net
options ndots:5

#### Using Full k8s URL

```
/opt/spark/bin/spark-submit \
  --master k8s://https://kubernetes.default.svc.cluster.local:443 \
  --deploy-mode cluster \
  --name spark-pi \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.executor.instances=3 \
  --conf spark.kubernetes.container.image=david62243/spark:2.4.3 \
  local:///opt/spark/examples/jars/spark-examples_2.11-2.4.3.jar
```

This worked.


