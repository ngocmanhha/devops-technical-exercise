variable "release_name" {
  description = "Helm release name."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the release."
  type        = string
}

variable "chart_path" {
  description = "Path to the packaged Greeter Helm chart."
  type        = string
}

variable "greeting_name" {
  description = "GREETING_NAME passed to the application."
  type        = string

  validation {
    condition     = length(trimspace(var.greeting_name)) > 0
    error_message = "greeting_name cannot be empty."
  }
}

variable "replica_count" {
  description = "Number of application replicas."
  type        = number

  validation {
    condition     = var.replica_count >= 1
    error_message = "replica_count must be at least 1."
  }
}

variable "app_version" {
  description = "Application VERSION value."
  type        = string
}

variable "resources" {
  description = "Application resource requests and limits."

  type = object({
    requests = object({
      cpu    = string
      memory = string
    })

    limits = object({
      cpu    = string
      memory = string
    })
  })
}

variable "hostnames" {
  description = "Hostnames used by the application's HTTPRoute."
  type        = list(string)
  default     = []
}
