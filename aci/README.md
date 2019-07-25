## Install AKS to use Virtual Nodes

Followed instructions [here](https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli)


## Topics

- ACI Issues
  - DNS 
    - Use full DNS names
    - Possibly add DNS to ACI Subnet?? 
  - Secrets 
    - Pass Docker Creds / TLS  in clear to ACI
    - Waiting for investigation of TLS secrets
  - Downward API (Spark Operator)
    - ??
  - Spark (no Spark Operator)
    - Added "selector" to job; however, spark k8s doesn't appear to support tolerations
    - To use ACI you must specify selector and and toleration 
    - https://spark.apache.org/docs/latest/running-on-kubernetes.html#how-it-works
    - Investigate how long before Spark/k8s support tolerations 
    
- Scale Performance
  - Based on most recent test; issue seems to be Portworx/Replication related
  - Also we need to use azure network plugin and managed premium drives
  - EKS with same number of similar sized VM's as AKS; ingest rats are better. Is there any additional tuning we can do for AKS
  
  
AKS
- Resizing Azure PVC
- Availability Zones

