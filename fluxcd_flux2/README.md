# Terraform Open Data Cube FluxCD Flux2 Installation

The purpose of this module is to set up [FluxCD](https://fluxcd.io/docs/) [Flux version 2](https://github.com/fluxcd/flux2)
- a tool for keeping Kubernetes clusters in sync with sources of configuration (like Git repositories),
and automating updates to configuration when there is new code to deploy.

---

```hcl-terraform
module "fluxcd_flux2" {
  source = "git@github.com:ga-scr/dpas-terraform-modules.git//fluxcd_flux2?ref=main"

  cluster_id      = local.cluster_id
  
  flux2_create_namespace = true  # Let's module to create a namespace
  flux2_namespace        = "flux-system"

  # flux chart installation versions
  # Charts: https://github.com/fluxcd-community/helm-charts/tree/main/charts
  flux2_version              = local.flux2_version
  flux2_notification_version = local.flux2_notification_version
  flux2_sync_version         = local.flux2_sync_version

  # flux sync configurations
  flux2_git_repo_url = "ssh://git@github.com/ga-scr/dpas-k8s-example-deployments"
  flux2_git_branch   = "main"
  flux2_git_path     = "workspaces/dpas"

  # flux notification configurations - e.g. slack channel
  flux2_webhook_url     = "<slack-url>"
  flux2_webhook_channel = "scr-dpas-flux"
  flux2_webhhok_type    = "slack"

  # notification events for alerting
  flux2_additional_alert_event_sources = []
}
```

## Variables

### Inputs
| Name                                 | Description                                                                                                                                                        |  Type  |                                                      Default                                                      | Required |
|--------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|:------:|:-----------------------------------------------------------------------------------------------------------------:|:--------:|
| cluster_id                           | EKS Cluster name                                                                                                                                                   | string |                                                                                                                   |   Yes    |
| flux2_create_namespace               | Determines whether to create k8s namespace. Default is set to true and creates a namespace resource provided in `flux2_namespace` var                              |  bool  |                                                       true                                                        |    No    |
| flux2_namespace                      | k8s namespace to install flux v2 components                                                                                                                        | string |                                                                                                                   |   Yes    |
| flux2_node_affinity                  | Kubernetes node affinity configuration to constrain flux2 components can be scheduled on                                                                           |  any   | {"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[{"topologyKey":"kubernetes.io/hostname"}]}} |    No    |
| flux2_node_selector                  | Kubernetes node selector configuration to constrain flux2 components can be scheduled on                                                                           |  any   |                                          {"kubernetes.io/os" : "linux"}                                           |    No    |
| flux2_version                        | flux V2 chart version                                                                                                                                              | string |                                                                                                                   |    No    |
| flux2_notification_version           | flux V2 notification chart version                                                                                                                                 | string |                                                                                                                   |    No    |
| flux2_sync_version                   | flux V2 sync chart version                                                                                                                                         | string |                                                                                                                   |    No    |
| flux2_git_repo_url                   | URL pointing to the git repository that flux will monitor and commit to                                                                                            | string |                                                                                                                   |   Yes    |
| flux2_git_branch                     | Branch of the specified git repository to monitor and commit to                                                                                                    | string |                                                                                                                   |   Yes    |
| flux2_git_path                       | Relative path inside specified git repository to search for manifest files                                                                                         | string |                                                                                                                   |   Yes    |
| flux2_git_poll_interval              | Period at which to poll git repo for new commits                                                                                                                   | string |                                                        1m                                                         |    No    |
| flux2_git_timeout                    | Duration after which git operations time out                                                                                                                       | string |                                                        20s                                                        |    No    |
| flux2_webhook_url                    | Webhook URL for flux notification                                                                                                                                  | string |                                                                                                                   |   Yes    |
| flux2_webhook_channel                | Channel name for flux notification                                                                                                                                 | string |                                                                                                                   |   Yes    |
| flux2_webhook_type                   | Alert type for flux notification e.g. slack, msteams, etc                                                                                                          | string |                                                                                                                   |   Yes    |
| flux2_additional_alert_event_sources | A list of alerts to be used for notification. Flux2 already monitors 'GitRepository', 'Kustomization' and 'HelmRelease' Kubernetes resources under flux2 namespace |  list  |                                                                                                                   |    No    |

## Issues

* The first time installation fail for `flux2_sync` and `flux2_slack_notification` 

The `flux2_sync` and `flux2_slack_notification` helmreleases depends on `flux2` components to be installed.
This is provisioned using `flux2` helmrelease resource in the same apply. However, this dependency hasn't been managed properly.
So by rerunning a pipeline again should fix the issue.

If issue still persist, then uninstall flux using [fluxcli](https://fluxcd.io/docs/cmd/) and bootstrap the process again.

```
> flux uninstall
> flux check
```