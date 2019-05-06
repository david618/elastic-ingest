#!/usr/bin/env bash

TenantFolder=tenants/${1}
mkdir -p ${TenantFolder}

KC=${TenantFolder}/kubeconfig

log_msg() {
	 MSG=$1
	 echo ${MSG}
   echo "$(date) : ${MSG}" >> ${TenantFolder}/log
}

update_status() {
	 MSG=$1
	 echo ${MSG}
   echo "${MSG}" > ${TenantFolder}/status
}

update_url() {
	 MSG=$1
	 echo ${MSG}
   echo "${MSG}" > ${TenantFolder}/url
}

update_a4iot_build() {
	 MSG=$1
	 echo ${MSG}
   echo "${MSG}" > ${TenantFolder}/a4iot_build
}

