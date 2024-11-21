#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_id} ${bootstrap_extra_args} --apiserver-endpoint ${endpoint} --b64-cluster-ca ${certificate_authority} \
  --kubelet-extra-args '--node-labels=${node_labels}' \
  --ip-family ${cluster_ip_family} --service-ipv4-cidr ${cluster_service_cidr}
${extra_userdata}