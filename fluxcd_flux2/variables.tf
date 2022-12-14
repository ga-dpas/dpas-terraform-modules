variable "cluster_id" {
  description = "EKS Cluster name"
  type        = string
}

variable "flux2_namespace" {
  type        = string
  description = "k8s namespace to install flux v2 components"
  default     = "flux-system"
}

variable "flux2_create_namespace" {
  type        = bool
  description = "Determines whether to create k8s namespace for flux2 components"
  default     = true
}

variable "flux2_node_affinity" {
  type        = any
  description = "Kubernetes node affinity configuration to constrain flux2 components can be scheduled on"
  default     = {}
}

variable "flux2_version" {
  type        = string
  description = "flux V2 chart version"
  default     = "0.15.0"
}

variable "flux2_notification_version" {
  type        = string
  description = "flux V2 notification chart version"
  default     = "0.5.2"
}

variable "flux2_sync_version" {
  type        = string
  description = "flux V2 sync chart version"
  default     = "0.3.6"
}

variable "flux2_git_repo_url" {
  type        = string
  description = "URL pointing to the git repository that flux will monitor and commit to"
  default     = ""
}

variable "flux2_git_branch" {
  type        = string
  description = "Branch of the specified git repository to monitor and commit to"
  default     = ""
}

variable "flux2_git_path" {
  type        = string
  description = "Relative path inside specified git repository to search for manifest files"
  default     = ""
}

variable "flux2_git_poll_interval" {
  type        = string
  description = "Period at which to poll git repo for new commits"
  default     = "1m"
}

variable "flux2_git_timeout" {
  type        = string
  description = "Duration after which git operations time out"
  default     = "20s"
}

variable "flux2_webhook_url" {
  type        = string
  description = "Webhook URL for flux notification"
  default     = ""
}

variable "flux2_webhook_channel" {
  type        = string
  description = "Channel name for flux notification"
  default     = ""
}

variable "flux2_webhook_type" {
  type        = string
  description = "Alert type for flux notification e.g. slack, msteams, etc"
  default     = ""
}

variable "flux2_additional_alert_event_sources" {
  type        = list(any)
  description = "A list of alerts to be used for notification"
  default     = []
}
