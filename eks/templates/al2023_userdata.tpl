MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${cluster_id}
    apiServerEndpoint: ${endpoint}
    certificateAuthority: ${certificate_authority}
    cidr: ${cluster_service_cidr}
  kubelet:
    flags:
      - --node-labels=${node_labels}
--BOUNDARY
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash

${extra_userdata}

--BOUNDARY--