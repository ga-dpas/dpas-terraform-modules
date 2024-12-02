resource "kubectl_manifest" "karpenter_on_demand_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default-ondemand
    spec:
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 5m
      expireAfter: 720h # force new nodes every 30 days
      limits:
        cpu: 100
      template:
        metadata:
          labels:
            nodegroup: karpenter-default
            nodetype: ondemand
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]
            - key: karpenter.k8s.aws/instance-size
              operator: NotIn
              values: [nano, micro, small]
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: [m5, m5a, m5ad, m5d, m6a, m6g, m6gd, m6i, m6id]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["2","4","8"]
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_spot_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default-spot
    spec:
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 5m
      expireAfter: 72h
      limits:
        cpu: 100
      template:
        metadata:
          labels:
            nodegroup: karpenter-default
            nodetype: spot
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]
            - key: karpenter.k8s.aws/instance-size
              operator: NotIn
              values: [nano, micro, small]
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: [m5, m5a, m5ad, m5d, m6a, m6g, m6gd, m6i, m6id]
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.dpas_eks_cluster.node_role_name}
      detailedMonitoring: true
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: required
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_id}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_id}
      tags:
        karpenter.sh/discovery: ${local.cluster_id}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}