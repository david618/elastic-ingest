#!/bin/env bash

eksctl create cluster \
--name dj0722c \
--region us-east-2 \
--version 1.12 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 14 \
--nodes-min 14 \
--nodes-max 14 \
--node-ami auto \
--ssh-public-key centos
