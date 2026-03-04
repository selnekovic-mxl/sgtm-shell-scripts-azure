# Server-side Google Tag Manager on Azure Container Apps

Step-by-step scripts to deploy [server-side GTM](https://developers.google.com/tag-platform/tag-manager/server-side) on **Microsoft Azure Container Apps** and to attach a custom domain with a free managed SSL certificate.

## Scripts

| Script | Purpose |
|--------|---------|
| **`sgtm_deployment.sh`** | Deploy sGTM: preview and production Container Apps, Log Analytics workspace. |
| **`sgtm_custom_domain.sh`** | Map a custom domain to the production app using an **A record** and a **free managed SSL certificate**. |

Run both in **Azure Cloud Shell** (Bash): [shell.azure.com](https://shell.azure.com).

## Prerequisites

- Azure subscription
- **Container config string** from your server-side GTM container (in GTM: container settings)
- For custom domain: a domain and access to its DNS

## Quick start

1. **Deploy sGTM**  
   Open `sgtm_deployment.sh`, set `CONTAINER_CONFIG` in Step 2 to your config string, then run the steps in order.

2. **Custom domain (recommended)**  
   After deployment, open `sgtm_custom_domain.sh`, set `CUSTOM_DOMAIN`, then run the steps in order.

## License

Use and adapt as needed. 
