#!/usr/bin/env bash

if [ ! -f ./svcprins ]; then
    echo "You need to create svcprins file; use svcprins.template updating inputs as needed"
fi

. ./svcprins

TenantFolder=tenants/${1}
mkdir -p ${TenantFolder}

export KC=${TenantFolder}/kubeconfig

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

