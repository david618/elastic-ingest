## Starting the A4IOT Mat

Tried adding 

```
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

To the spec.

The pod would not deploy;  Error Message.

```
kubectl logs mat-5b7596dc44-qmjrq
Error from server (InternalError): Internal error occurred: error getting container logs?): api call to https://management.azure.com/subscriptions/42e12bff-9125-4a9a-987d-685e9c480b0a/resourceGroups/MC_dj0709a_dj0709a-cluster_westus2/providers/Microsoft.ContainerInstance/containerGroups/default-mat-5b7596dc44-qmjrq?api-version=2018-10-01: got HTTP response status code 404 error code "ResourceNotFound": The Resource 'Microsoft.ContainerInstance/containerGroups/default-mat-5b7596dc44-qmjrq' under resource group 'MC_dj0709a_dj0709a-cluster_westus2' was not found.
```

#### Resources

Original spec had resources defined.  Request 1 cpu, 1Gi; Limit 6 cpu, 2Gi.

With these resrouce setting the pod will not start.

Removed them.

#### Secrets

The original manifest uses a secret for Docker


```
imagePullSecrets:
- name: docker-creds 
```

It also uses a "secret" volume to load the certificate for the server. 

These both had to be removed for the pod to start.

Tested an generic secret and that works; failed with tls and docker secrets.

#### Liveline and Rediness

These are probablly ok; however, without the certificate the container readiness never become healthy; therefore, the container restarts over and over.

#### Modified Spec

This spec worked.

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: mat4
    taskType: mat4
  name: mat4
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mat4
      taskType: mat4
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: mat4
        taskType: mat4
    spec:
      containers:
      - env:
        - name: ES_CLUSTER_NAME
          value: A4IOTDataStore
        - name: EXTERNAL_HOSTNAME
          value: dj0709a-public.westus2.cloudapp.azure.com
        - name: ES_USERNAME
          value: elastic
        - name: ES_PASSWORD
          value: changeme
        - name: ZK_QUORUM
          value: gateway-cp-zookeeper:2181
        - name: ES_TCP_PORT
          value: "9300"
        - name: SAT_GUID
"mat4.yaml" 75L, 1913C
          value: "9300"
        - name: SAT_GUID
          value: A4IOTDataStore
        - name: ES_NODES
          value: datastore-elasticsearch-client.default.svc
        - name: ES_HTTP_PORT
          value: "9200"
        image: rtrujill007/realtime-mat:0.10.24_RT
        imagePullPolicy: Always
        name: mat4
        ports:
        - containerPort: 9000
          name: http
          protocol: TCP
        - containerPort: 9443
          name: https
          protocol: TCP
        - containerPort: 8000
          name: debug
          protocol: TCP
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
      - key: azure.com/aci
        effect: NoSchedule
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
   ```
   
