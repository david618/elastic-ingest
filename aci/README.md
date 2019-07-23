## Install AKS to use Virtual Nodes

Followed instructions [here](https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli)


## Topics

- ACI Issues
  - DNS 
  - Secrets 
  - Downward API
- Scale Performance
  - Based on most recent test; issue seems to be Portworx/Replication related
  - Also we need to use azure network plugin and managed premium drives
  - EKS with same number of similar sized VM's as AKS; ingest rats are better. Is there any additional tuning we can do for AKS?
- Resizing Azure PVC
- Availability Zones

