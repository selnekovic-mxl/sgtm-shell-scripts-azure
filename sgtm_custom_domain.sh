#!/bin/bash
#
# Step-by-step manual: map a custom domain to the sGTM production Container App
# using an A record and a free managed SSL certificate.
# Run these in Azure Cloud Shell (https://shell.azure.com) — use Bash.
#

# =============================================================================
# STEP 0: Prerequisites
# =============================================================================
# - Production Container App is already deployed (e.g. sgtm-server-eu-prod).
# - You have a custom domain and access to its DNS.
# - For a free managed certificate, the app must have external HTTP ingress (already set by the deploy).
# - You will create an A record (and TXT for verification).

# =============================================================================
# STEP 1: Set variables (match your deployment)
# =============================================================================
RESOURCE_GROUP="rg-sgtm-server"
ENVIRONMENT_NAME="sgtm-env"
SERVICE_NAME="sgtm-server-eu"
PRODUCTION_APP_NAME="${SERVICE_NAME}-prod"

# Your custom domain (e.g. sst.example.com).
CUSTOM_DOMAIN="sst.yourdomain.com"

# =============================================================================
# STEP 2: Ensure Container Apps CLI extension is installed
# =============================================================================
az extension add --name containerapp --upgrade

# =============================================================================
# STEP 3: Verify ingress is enabled on the production app
# =============================================================================
az containerapp ingress show \
  -n "$PRODUCTION_APP_NAME" \
  -g "$RESOURCE_GROUP"

# If ingress is not enabled, enable it (target port 8080 for sGTM):
# az containerapp ingress enable -n "$PRODUCTION_APP_NAME" -g "$RESOURCE_GROUP" \
#   --type external --target-port 8080 --transport auto

# =============================================================================
# STEP 4: Get values needed for DNS (A record + SSL)
# =============================================================================
# Environment static IP — use this as the value for your A record.
ENV_IP=$(az containerapp env show \
  -n "$ENVIRONMENT_NAME" \
  -g "$RESOURCE_GROUP" \
  -o tsv \
  --query "properties.staticIp")
echo "Environment static IP (use for A record): $ENV_IP"

# Domain verification code — use this for the TXT record (ownership verification).
VERIFICATION_ID=$(az containerapp show \
  -n "$PRODUCTION_APP_NAME" \
  -g "$RESOURCE_GROUP" \
  -o tsv \
  --query "properties.customDomainVerificationId")
echo "Domain verification ID (use for TXT record): $VERIFICATION_ID"

# Exact TXT record Azure (must exist before Step 6):
TXT_FQDN="asuid.${CUSTOM_DOMAIN}"
echo ""
echo "Create this TXT record before running Step 6 (Azure validates it on hostname add):"
echo "  TXT FQDN:  $TXT_FQDN"
echo "  Value:    $VERIFICATION_ID"
echo "  (In your DNS zone: name = 'asuid.<subdomain>' e.g. asuid.sst for sst.yourdomain.com)"
echo ""

# =============================================================================
# STEP 5: Create DNS records at your DNS provider (A + TXT only)
# =============================================================================
# Create exactly these two records - A and TXT.
#
#   Type    Host (name)        Value
#   A       <subdomain e.g. sst>        <ENV_IP from step 4>
#   TXT     asuid.<subdomain e.g. sst>  <VERIFICATION_ID from step 4>
#
# The A record must point directly to the environment IP (no proxy/CDN in front),
# or HTTP certificate validation may fail.
#
# After creating the records, wait for DNS propagation (usually minutes).

# =============================================================================
# STEP 5b: Optional — verify TXT record before Step 6
# =============================================================================
# Run this to verify the TXT record is visible (should show the verification ID):
dig TXT "$TXT_FQDN" +short
# Only run Step 6 after the command above returns the correct value.

# =============================================================================
# STEP 6: Add the custom hostname to the Container App
# =============================================================================
# Only run this after the A and TXT records exist and have propagated. Azure
# validates the TXT record (asuid.<CUSTOM_DOMAIN>) when you run this command.
az containerapp hostname add \
  --hostname "$CUSTOM_DOMAIN" \
  -g "$RESOURCE_GROUP" \
  -n "$PRODUCTION_APP_NAME"

# =============================================================================
# STEP 7: Bind the hostname with a managed SSL certificate (HTTP validation)
# =============================================================================
# Uses HTTP validation (for A record). Issues the free managed certificate; can take several minutes.
az containerapp hostname bind \
  --hostname "$CUSTOM_DOMAIN" \
  -g "$RESOURCE_GROUP" \
  -n "$PRODUCTION_APP_NAME" \
  --environment "$ENVIRONMENT_NAME" \
  --validation-method HTTP

# =============================================================================
# STEP 8: Verify
# =============================================================================
# List custom domains on the app:
az containerapp hostname list -n "$PRODUCTION_APP_NAME" -g "$RESOURCE_GROUP" -o table

echo "Production with custom domain: https://$CUSTOM_DOMAIN"
echo "Health check:                 https://$CUSTOM_DOMAIN/healthy"

