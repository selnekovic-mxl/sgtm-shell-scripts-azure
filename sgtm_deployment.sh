#!/bin/bash
#
# Step-by-step commands to deploy server-side Google Tag Manager (sGTM) on Azure Container Apps
# Run these in Azure Cloud Shell (https://shell.azure.com) — use Bash.
# You need the container config string from your server-side GTM container (find it in the container in GTM).
# Run one section at a time and replace placeholder values where indicated.
#

# =============================================================================
# STEP 0: Prerequisites (run these once, especially if using Cloud Shell for the first time)
# =============================================================================
# 1. Open https://shell.azure.com and sign in.
#
# 2. First-time Cloud Shell: when asked to create storage for the shell, choose
#    "Create storage" so your session and files persist.
#
# 3. Register resource providers (required for Container Apps and Log Analytics).
#    Run each command; registration can take a few minutes.
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
#    Wait until both show "Registered" (optional but recommended before continuing):
az provider show -n Microsoft.App --query "registrationState" -o tsv
az provider show -n Microsoft.OperationalInsights --query "registrationState" -o tsv
#
# 4. Optional: set the subscription to use
#    az account set --subscription "<subscription-id>"
#

# =============================================================================
# STEP 1: Predefined Azure values (no need to change)
# =============================================================================
RESOURCE_GROUP="rg-sgtm-server"
LOCATION="westeurope"
ENVIRONMENT_NAME="sgtm-env"
SERVICE_NAME="sgtm-server-eu"
LOG_ANALYTICS_WORKSPACE_NAME="sgtm-logs"

# =============================================================================
# STEP 2: Container config string (required)
# =============================================================================
# Paste the config string from your server-side GTM container.
#
CONTAINER_CONFIG='PLACEHOLDER'

# =============================================================================
# STEP 3: Install or upgrade Azure Container Apps CLI extension
# =============================================================================
az extension add --name containerapp --upgrade

# =============================================================================
# STEP 4: Create resource group
# =============================================================================
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# =============================================================================
# STEP 5: Create Container Apps environment
# =============================================================================
# Uses predefined resource group, environment name, workspace name, and location (westeurope).
# Creates Log Analytics workspace "sgtm-logs" and Container Apps environment "sgtm-env".

az monitor log-analytics workspace create \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" \
  --location "$LOCATION"

# =============================================================================
LOGS_WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --query customerId --output tsv)

# =============================================================================
LOGS_WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group "$RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --query primarySharedKey --output tsv)

# =============================================================================
az containerapp env create \
  --name "$ENVIRONMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --logs-workspace-id "$LOGS_WORKSPACE_ID" \
  --logs-workspace-key "$LOGS_WORKSPACE_KEY"

# =============================================================================
# STEP 6: Deploy PREVIEW (debug) Container App
# =============================================================================
# Ensure CONTAINER_CONFIG is set (from Step 2). Then run:

az containerapp create \
  --name "${SERVICE_NAME}-preview" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable" \
  --target-port 8080 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --env-vars "RUN_AS_PREVIEW_SERVER=true" "CONTAINER_CONFIG=$CONTAINER_CONFIG"

# Get the preview URL:
PREVIEW_FQDN=$(az containerapp show \
  --name "${SERVICE_NAME}-preview" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)
echo "Preview URL: https://$PREVIEW_FQDN/healthy"

# =============================================================================
# STEP 7: Deploy PRODUCTION Container App
# =============================================================================
# Uses PREVIEW_FQDN from step 6 and same CONTAINER_CONFIG.

az containerapp create \
  --name "${SERVICE_NAME}-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable" \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 4 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    "GOOGLE_CLOUD_PROJECT=$RESOURCE_GROUP" \
    "PREVIEW_SERVER_URL=https://$PREVIEW_FQDN" \
    "CONTAINER_CONFIG=$CONTAINER_CONFIG"

# =============================================================================
# STEP 8: Get production URL and verify
# =============================================================================
PROD_FQDN=$(az containerapp show \
  --name "${SERVICE_NAME}-prod" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)

echo "Production URL: https://$PROD_FQDN"
echo "Health check:   https://$PROD_FQDN/healthy"


