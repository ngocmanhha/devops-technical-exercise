output "release_name" {
  description = "Helm release name."
  value       = helm_release.this.name
}

output "namespace" {
  description = "Kubernetes namespace."
  value       = helm_release.this.namespace
}

output "status" {
  description = "Helm release status."
  value       = helm_release.this.status
}
