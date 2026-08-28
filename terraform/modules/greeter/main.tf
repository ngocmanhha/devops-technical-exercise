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
    })
  ]
}
