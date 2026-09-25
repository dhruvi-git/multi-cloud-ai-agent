# ---- GCP: orchestration layer ----
# Terraform provisions the registry that will hold the orchestrator image.
# The Cloud Run *service* itself is deployed by GitHub Actions (deploy-cloudrun
# action) after the image is built, since Cloud Run needs an image to exist
# before it can be created - Terraform can't build/push Docker images itself.

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.gcp_region
  repository_id = "ai-agent-repo"
  format        = "DOCKER"
  depends_on    = [google_project_service.artifact_registry]
}

output "artifact_registry_repo" {
  value = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.repo.repository_id}"
}
