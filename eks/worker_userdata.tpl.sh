#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_id} ${extra_bootstrap_args} --apiserver-endpoint ${endpoint} --b64-cluster-ca ${certificate_authority}
${extra_userdata}