output "environments" {
  description = "Deployed Greeter environments."

  value = {
    for name, deployment in module.greeter :
    name => {
      release_name = deployment.release_name
      namespace    = deployment.namespace
      status       = deployment.status
    }
  }
}
