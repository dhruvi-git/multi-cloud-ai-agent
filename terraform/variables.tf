variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "azure_resource_group" {
  type    = string
  default = "rg-ai-agent-demo"
}

variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "s3_bucket_name" {
  type        = string
  description = "Must be globally unique, e.g. ai-agent-kb-yourname-2026"
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}
