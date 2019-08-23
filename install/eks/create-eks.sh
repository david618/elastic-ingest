#!/bin/env bash

eksctl create cluster \
--name dj0815 \
--region us-east-2 \
--version 1.13 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 6 \
--nodes-min 6 \
--nodes-max 6 \
--node-ami auto \
--ssh-public-key centos
