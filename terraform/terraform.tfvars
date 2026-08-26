environments = {
  dev = {
    namespace     = "greeter-dev"
    greeting_name = "what3words Dev"
    replica_count = 1
    app_version   = "dev"
    hostnames = [
      "dev.greeter.local",
    ]

    resources = {
      requests = {
        cpu    = "25m"
        memory = "32Mi"
      }

      limits = {
        cpu    = "100m"
        memory = "64Mi"
      }
    }
  }

  prod = {
    namespace     = "greeter-prod"
    greeting_name = "what3words Production"
    replica_count = 2
    app_version   = "prod"
    hostnames = [
      "prod.greeter.local",
    ]

    resources = {
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }

      limits = {
        cpu    = "250m"
        memory = "128Mi"
      }
    }
  }
}
