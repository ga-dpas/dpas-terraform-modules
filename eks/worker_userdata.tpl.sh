#!/bin/bash
set -o xtrace
# Get instance and ami id from the aws ec2 metadate endpoint
id=$(curl http://169.254.169.254/latest/meta-data/instance-id -s)
ami=$(curl http://169.254.169.254/latest/meta-data/ami-id -s)
/etc/eks/bootstrap.sh --apiserver-endpoint '${endpoint}' --b64-cluster-ca '${certificate_authority}' '${cluster_id}' ${extra_bootstrap_args} \
--kubelet-extra-args \
  "--node-labels=cluster=${cluster_id},instance-id=$id,ami-id=$ami,${extra_node_labels} \
   --cloud-provider=aws ${extra_kubelet_args}"
${extra_userdata}