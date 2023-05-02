# SSH
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="

  default_alert_event_sources = [
    {
      kind : "GitRepository"
      name : "*"
      namespace : var.flux2_namespace
    },
    {
      kind : "Kustomization"
      name : "*"
      namespace : var.flux2_namespace
    },
    {
      kind : "HelmRelease"
      name : "*"
      namespace : var.flux2_namespace
    },
  ]
}

resource "tls_private_key" "flux2" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Generate a Kubernetes secret with the Git credentials
resource "kubernetes_secret" "flux2" {
  depends_on = [helm_release.flux2]

  metadata {
    name      = "flux-system"
    namespace = var.flux2_namespace
  }

  data = {
    identity       = tls_private_key.flux2.private_key_pem
    "identity.pub" = tls_private_key.flux2.public_key_pem
    known_hosts    = local.known_hosts
    # GitHub Deploy Key
    public_key_openssh = tls_private_key.flux2.public_key_openssh
  }
}

## Install flux using helm charts: https://github.com/fluxcd-community/helm-charts/
# Chart: https://github.com/fluxcd-community/helm-charts/tree/main/charts/flux2
# https://fluxcd.io/docs/components/
resource "helm_release" "flux2" {
  name       = "${var.cluster_id}-flux2"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  version    = var.flux2_version

  namespace        = var.flux2_namespace
  create_namespace = var.flux2_create_namespace

  values = [
    templatefile("${path.module}/config/flux2.yaml", {
      node_affinity = jsonencode(var.flux2_node_affinity)
      node_selector = jsonencode(var.flux2_node_selector)
    })
  ]
}

# Chart: https://github.com/fluxcd-community/helm-charts/tree/main/charts/flux2-sync
# https://fluxcd.io/docs/components/source/gitrepositories/
resource "helm_release" "flux2_sync" {
  depends_on = [helm_release.flux2]
  name       = "${var.cluster_id}-deployer"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  version    = var.flux2_sync_version
  namespace  = var.flux2_namespace

  values = [
    templatefile("${path.module}/config/flux2_sync.yaml", {
      git_repo_url      = var.flux2_git_repo_url
      git_branch        = var.flux2_git_branch
      git_path          = var.flux2_git_path
      git_poll_interval = var.flux2_git_poll_interval
      git_timeout       = var.flux2_git_timeout
      flux_git_secret   = kubernetes_secret.flux2.metadata[0].name
    })
  ]
}

# Chart: https://github.com/fluxcd-community/helm-charts/tree/main/charts/flux2-notification
# https://fluxcd.io/docs/components/notification/
resource "helm_release" "flux2_notification" {
  depends_on = [helm_release.flux2]
  name       = "${var.cluster_id}-flux2-notification"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-notification"
  version    = var.flux2_notification_version
  namespace  = var.flux2_namespace

  values = [
    templatefile("${path.module}/config/flux2_notification.yaml", {
      webhook_address     = base64encode(var.flux2_webhook_url)
      webhook_channel     = var.flux2_webhook_channel
      webhook_type        = var.flux2_webhook_type
      alert_event_sources = jsonencode(distinct(concat(local.default_alert_event_sources, var.flux2_additional_alert_event_sources)))
    })
  ]
}
