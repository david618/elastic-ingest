#!/usr/bin/env bash

topic="planes10"
KC=kc.dj0802b

for runnum in {1..25}; do
	echo "------------------------------------------------------"
	echo ${runnum}

	# Stop Monitors
	kubectl --kubeconfig ${KC} delete -f rttest-mon-kafka-tol.yaml
  kubectl --kubeconfig ${KC} delete -f rttest-mon-es-tol.yaml
  sleep 10

	# Stop Send and Spark Job
	kubectl --kubeconfig ${KC} delete -f rttest-send-kafka-25k-10m-10part-tol.yaml
	kubectl --kubeconfig ${KC} delete -f sparkop-es-2.4.1-10part.yaml
  sleep 60 # Wait a min

  # Recreate Kafka Topic
  # If it exists; delete it
  cnt=$(kubectl --kubeconfig ${KC} exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --list | grep ${topic} | wc -l )

  if [ "${cnt}" -gt 0 ]; then
    # If exists; delete the topic
    kubectl --kubeconfig ${KC} exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic ${topic} --delete
  fi

  # Create Topic
  kubectl --kubeconfig ${KC} exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic ${topic} --create --replication-factor 1 --partitions 10

  if [ "$?" -ne 0 ]; then
    echo "Create Topic Failed; this will happen if some process has an open connection to the topic. Make sure you delete all producers/consumers and try again."
    exit 1
  fi  

	# Start Spark Job
  kubectl --kubeconfig ${KC} apply -f sparkop-es-2.4.1-10part.yaml
	sleep 60 # Wait a min
	
	# Start monitors
	kubectl --kubeconfig ${KC} apply -f rttest-mon-kafka-tol.yaml
  kubectl --kubeconfig ${KC} apply -f rttest-mon-es-tol.yaml
	sleep 60 # Wait a min
  
	# Start Send
	kubectl --kubeconfig ${KC} apply -f rttest-send-kafka-25k-10m-10part-tol.yaml
	sleep 1020 # Wait 16 min  (Assuming rate around of at least 200k/s that would take 1000 seconds) 

  # Capture Results
	echo "Kafka Logs"
  kubectl --kubeconfig ${KC} logs $(kubectl --kubeconfig ${KC} get pod -l app=rttest-mon-kafka -o name)
	echo "Elasticsearch Logs"
	kubectl --kubeconfig ${KC} logs $(kubectl --kubeconfig ${KC} get pod -l app=rttest-mon-es -o name)
	sleep 10

done
