#!/bin/bash
set -o xtrace
# Get instance and ami id from the aws ec2 metadate endpoint
%{if enable_imsv2~}
token=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
id=`curl -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/instance-id`
ami=`curl -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/ami-id`
%{else~}
id=$(curl http://169.254.169.254/latest/meta-data/instance-id -s)
ami=$(curl http://169.254.169.254/latest/meta-data/ami-id -s)
%{endif~}
/etc/eks/bootstrap.sh --apiserver-endpoint '${endpoint}' --b64-cluster-ca '${certificate_authority}' '${cluster_id}' ${extra_bootstrap_args} \
--kubelet-extra-args \
  "--node-labels=cluster=${cluster_id},instance-id=$id,ami-id=$ami,${extra_node_labels} \
   --cloud-provider=aws ${extra_kubelet_args}"
${extra_userdata}