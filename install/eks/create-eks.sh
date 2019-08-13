#!/bin/env bash

eksctl create cluster \
--name dj0722c \
--region us-east-2 \
--version 1.13 \
--nodegroup-name standard-workers \
--node-type m5.4xlarge \
--nodes 25 \
--nodes-min 25 \
--nodes-max 25 \
--node-ami auto \
--ssh-public-key centos
