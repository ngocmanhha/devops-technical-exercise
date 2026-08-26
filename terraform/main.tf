module "greeter" {
  source = "./modules/greeter"

  for_each = var.environments

  release_name = "greeter"
  namespace    = each.value.namespace

  chart_path = abspath(var.chart_path)

  greeting_name = each.value.greeting_name
  replica_count = each.value.replica_count
  app_version   = each.value.app_version
  hostnames     = each.value.hostnames

  resources = each.value.resources
}
