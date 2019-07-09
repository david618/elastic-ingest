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

#### Liveline and Rediness

These are probablly ok; however, without the certificate the container readiness never become healthy; therefore, the container restarts over and over.


