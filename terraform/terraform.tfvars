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

    monitoring = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
      prometheusRule = {
        enabled = true
        rules = [
          {
            alertName = "GreeterHigh5xxErrorRate"
            expr      = <<EOF
                    sum(rate(greeter_http_requests_total{status=~"5.."}[1m]))
                    /
                    sum(rate(greeter_http_requests_total[1m]))
                    > 0.10
                EOF
            for       = "2m"
            labels = {
              severity = "critical"
            }
            annotations = {
              summary     = "Greeter has a high HTTP 5xx error rate"
              description = "More than 10% of Greeter requests have returned HTTP 5xx responses for 2 minutes."
            }
          }
        ]
      }
    }
  }
}
