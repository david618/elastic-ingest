## Dynamically Resize PVC

Reference in Azure Docs: https://docs.microsoft.com/en-us/azure/aks/azure-disks-dynamic-pv

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

Added ``allowVolumeExpansion`` parameter to Portworx Stroage Class.

Edited the PVC and resized.

Within a few seconds the PVC showed the new size; no restart was required.



### EKS 

Created a Storage Class

```
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: eks-exp
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Delete
allowVolumeExpansion: true
```

Edited the PVC and resized.  

Describe of the pvc; said it was waiting for pod to "(re)start" to apply the resize.

Deleted the pod and upon restart the PVC resized.




