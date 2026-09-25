# ---- AZURE: NLP layer ----
# Provisions a resource group + a free-tier Azure AI Language resource,
# used to pull key phrases out of the raw support ticket text.

resource "azurerm_resource_group" "main" {
  name     = var.azure_resource_group
  location = var.azure_location
}

resource "azurerm_cognitive_account" "language" {
  name                = "ai-agent-language-svc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  kind                = "TextAnalytics"
  sku_name            = "F0" # free tier - 5,000 transactions/month

  # Required for AI/Cognitive Services resources as of recent Azure policy
  custom_subdomain_name = "ai-agent-language-${var.gcp_project_id}"
}

output "azure_language_endpoint" {
  value = azurerm_cognitive_account.language.endpoint
}

output "azure_language_key" {
  value     = azurerm_cognitive_account.language.primary_access_key
  sensitive = true
}
