module "fluxcd_flux2" {
  source = "../../fluxcd_flux2"
  count  = local.enable_flux2 ? 1 : 0

  cluster_id = local.cluster_id

  flux2_namespace        = local.flux2_namespace
  flux2_create_namespace = local.flux2_create_namespace
  flux2_node_affinity    = local.default_node_affinity

  # flux chart installation versions
  # Charts: https://github.com/fluxcd-community/helm-charts/tree/main/charts
  flux2_version              = local.flux2_version
  flux2_notification_version = local.flux2_notification_version
  flux2_sync_version         = local.flux2_sync_version

  # flux sync configurations
  # NOTE: Update as per your setup!
  flux2_git_repo_url = "ssh://git@github.com/ga-scr/dpas-k8s-example-deployment"
  flux2_git_branch   = "main"
  flux2_git_path     = "workspaces/dpas-sandbox"

  # flux notification configurations
  # NOTE: update as per your setup!
  flux2_webhook_url     = "provide-webhook-url"
  flux2_webhook_type    = "slack"
  flux2_webhook_channel = "dpas-system-notifications"

  # notification events for alerting
  flux2_additional_alert_event_sources = []

  depends_on = [
    module.dpas_eks_cluster.cluster_id
  ]
}