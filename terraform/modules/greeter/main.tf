resource "helm_release" "this" {
  name      = var.release_name
  namespace = var.namespace

  chart = var.chart_path

  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 180

  values = [
    yamlencode({
      replicaCount = var.replica_count

      application = {
        greetingName = var.greeting_name
        version      = var.app_version
      }

      resources = var.resources
      gateway = {
        hostnames = var.hostnames
      }

      monitoring = {
        enabled = try(var.monitoring.enabled, false)
        serviceMonitor = {
          enabled       = try(var.monitoring.serviceMonitor.enabled, false)
          port          = try(var.monitoring.serviceMonitor.port, "http")
          path          = try(var.monitoring.serviceMonitor.path, "/metrics")
          interval      = try(var.monitoring.serviceMonitor.interval, "15s")
          scrapeTimeout = try(var.monitoring.serviceMonitor.scrapeTimeout, "5s")
        }
        prometheusRule = {
          enabled = try(var.monitoring.prometheusRule.enabled, false)
          rules   = try(var.monitoring.prometheusRule.rules, [])
        }
      }
    })
  ]
}
