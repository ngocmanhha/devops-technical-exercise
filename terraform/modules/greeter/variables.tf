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

variable "monitoring" {
  type = object({
    enabled = optional(bool, false)
    serviceMonitor = object({
      enabled       = optional(bool, false)
      port          = optional(string, "")
      path          = optional(string, "")
      interval      = optional(string, "")
      scrapeTimeout = optional(string, "")
    })
    prometheusRule = object({
      enabled = optional(bool, false)
      rules = optional(list(object({
        alertName   = optional(string, null)
        expr        = optional(string, null)
        for         = optional(string, null)
        labels      = optional(map(any), {})
        annotations = optional(map(any), {})
      })), [])
    })
  })
  default = {
    enabled = false
    serviceMonitor = {
      enabled = false
    }
    prometheusRule = {
      enabled = false
    }
  }
  description = "Enable and configure monitoring for greeter service"
}
