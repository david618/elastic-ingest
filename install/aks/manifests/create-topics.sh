#!/usr/bin/env bash

for num in 3 5 7 10; do

	topic=planes${num}


	# See if topic exists
  cnt=$(kubectl exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --list | grep ${topic} | wc -l )

  if [ "${cnt}" -gt 0 ]; then
 	  # If exists; delete the topic
    kubectl exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic ${topic} --delete
  fi  
	
	# Create Topic
  kubectl exec gateway-cp-kafka-0 --container cp-kafka-broker -- kafka-topics --zookeeper gateway-cp-zookeeper:2181 --topic ${topic} --create --replication-factor 1 --partitions ${num}

  if [ "$?" -ne 0 ]; then
		echo "Create Topic Failed; this will happen if some process has an open connection to the topic. Make sure you delete all producers/consumers and try again."
		exit 1
	fi

done
