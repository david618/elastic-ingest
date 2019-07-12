## Dynamically Resize PVC

### Added allowVolumeExpansion 

Used ``kubectl edit pvc managed-premium`` and added line ``allowVolumeExpansion: true``

### Created New Storage Class

```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium-exp
parameters:
  kind: Managed
  storageaccounttype: Premium_LRS
provisioner: kubernetes.io/azure-disk
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Both cases

When edit existing PVC and try to resize; get Error Messages.

```
  Warning    VolumeResizeFailed     49s (x4 over 5m34s)    volume_expand                
  Error expanding volume "default/rally-data-esrally-ss-0" of plugin kubernetes.io/azure-disk : 
  compute.DisksClient#CreateOrUpdate: Failure sending request: StatusCode=0 -- Original Error: autorest/azure: 
  Service returned an error. Status=<nil> Code="OperationNotAllowed" 
  Message="Cannot resize disk kubernetes-dynamic-pvc-6b4a77af-a4d6-11e9-8259-52a9ca4859ae while 
  it is attached to running 
  VM /subscriptions/42e12bff-9125-4a9a-987d-685e9c480b0a/resourceGroups/MC_dj0712b_dj0712b-cluster_westus2/providers/Microsoft.Compute/virtualMachines/aks-nodepool1-27134090-1."
  Warning    VolumeResizeFailed     24s (x4 over 5m34s)    volume_expand                
  Error expanding volume "default/rally-data-esrally-ss-0" of plugin kubernetes.io/azure-disk : 
  AzureDisk -  failed to get Azure Cloud Provider. GetCloudProvider returned <nil> instead
```

Tried restarting the Pod.  Still didn't resize.


### Using Portworx

Added same parameter to Portworx Stroage Class and resize works fine.



