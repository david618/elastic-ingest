### Added Taints to Three Nodes

```
kubectl taint nodes aks-nodepool1-12209422-21 key=test:NoSchedule
kubectl taint nodes aks-nodepool1-12209422-22 key=test:NoSchedule
kubectl taint nodes aks-nodepool1-12209422-23 key=test:NoSchedule
```

### Added Labels to Same Three Nodes

```
kubectl label nodes aks-nodepool1-12209422-21 func=test
kubectl label nodes aks-nodepool1-12209422-22 func=test
kubectl label nodes aks-nodepool1-12209422-23 func=test
```

### Added NodeSelector and Tolerations 

To rttest manifest added nodeSelector and tolerations to spec:

      tolerations:
      - key: "key"
        operator: "Exists"
        effect: "NoSchedule"
      nodeSelector:
        func: test


### Removing Taints and Labels (optional)

```
kubectl taint nodes aks-nodepool1-12209422-20 key:NoSchedule-

kubectl label node aks-nodepool1-12209422-20 func-
```

### Repeated Tests for 7 and 10 nodes

```
kubectl apply -f rttest-send-kafka-25k-10m-7part-tol.yaml
kubectl apply -f sparkop-es-2.4.1-7part.yaml
```

### Results

Between each test stopped and restart sparkop and rttest.


|Test Number|Number of Elasticsearch Nodes|Ingest Rate|
|-----------|-----------------------------|-----------|
|1          |7                            |234        |
|2          |7                            |277        |
|3          |7                            |332        |
|4          |10                           |351        |
|5          |10                           |353        |
|6          |10                           |338        |

Average Ingest Rates
- 7 node: 281
- 10 node: 347
