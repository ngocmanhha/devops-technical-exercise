variable "kubeconfig_path" {
  description = "Path to the Kubernetes kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubernetes context used by the Helm provider."
  type        = string
  default     = "k3d-what3words-exercise"
}

variable "chart_path" {
  description = "Path to the packaged and signed Greeter Helm chart."
  type        = string
  default     = "../dist/greeter-0.1.0.tgz"
}

variable "environments" {
  description = "Greeter environment configuration."

  type = map(object({
    namespace     = string
    greeting_name = string
    replica_count = number
    app_version   = string
    hostnames     = list(string)

    resources = object({
      requests = object({
        cpu    = string
        memory = string
      })

      limits = object({
        cpu    = string
        memory = string
      })
    })
  }))

  validation {
    condition = alltrue([
      for environment in values(var.environments) :
      environment.replica_count >= 1
    ])

    error_message = "replica_count must be at least 1."
  }
}
