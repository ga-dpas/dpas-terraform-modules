resource "kubectl_manifest" "karpenter_provisioner_default_ondemand" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default-ondemand
    spec:
      consolidation:
        enabled: true
      labels:
        nodegroup: karpenter-default
        nodetype: ondemand
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        # Include general purpose instance families
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: [m5, m5a, m5ad, m5d, m6a, m6g, m6gd, m6i, m6id]
      limits:
        resources:
          cpu: 60
      providerRef:
        name: default
      ttlSecondsUntilExpired: 2592000 # force new nodes every 30 days
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_provisioner_default_spot" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default-spot
    spec:
      labels:
        nodegroup: karpenter-default
        nodetype: spot
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["arm64", "amd64"]
        # Include general purpose instance families
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: [m5, m5a, m5ad, m5d, m6a, m6g, m6gd, m6i, m6id]
      limits:
        resources:
          cpu: 50
      providerRef:
        name: default
      ttlSecondsAfterEmpty: 60
      ttlSecondsUntilExpired: 2592000 # force new nodes every 30 days
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  count = local.enable_karpenter ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${local.cluster_id}
      securityGroupSelector:
        karpenter.sh/discovery: ${local.cluster_id}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

