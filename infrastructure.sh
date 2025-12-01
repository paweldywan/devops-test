#!/bin/bash

# ============================================
# Azure Infrastructure Deployment Script
# Creates: Resource Group, App Service Plan, Web App
# ============================================

set -e  # Exit on error

# Configuration - customize these values
RESOURCE_GROUP="rg-myapp-dev"
LOCATION="centralus"
APP_SERVICE_PLAN="asp-myapp-dev"
WEB_APP_NAME="webapp-myapp-dev-$(date +%s)"  # Unique name with timestamp
SKU="F1"  # Free tier (options: F1, D1, B1, B2, B3, S1, S2, S3, P1V2, P2V2, P3V2)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Azure infrastructure deployment...${NC}"

# Verify Azure CLI login
echo "Verifying Azure CLI authentication..."
az account show > /dev/null 2>&1 || { echo "Please run 'az login' first"; exit 1; }

# Display current subscription
echo -e "${GREEN}Using subscription:${NC}"
az account show --query "{Name:name, Id:id}" -o table

# Create Resource Group
echo -e "\n${YELLOW}Creating Resource Group: ${RESOURCE_GROUP}${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags Environment=Development Project=MyApp

echo -e "${GREEN}✓ Resource Group created${NC}"

# Create App Service Plan
echo -e "\n${YELLOW}Creating App Service Plan: ${APP_SERVICE_PLAN}${NC}"
az appservice plan create \
    --name "$APP_SERVICE_PLAN" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "$SKU" \
    --is-linux

echo -e "${GREEN}✓ App Service Plan created${NC}"

# Create Web App
echo -e "\n${YELLOW}Creating Web App: ${WEB_APP_NAME}${NC}"
az webapp create \
    --name "$WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_SERVICE_PLAN" \
    --runtime "NODE:22-lts"

echo -e "${GREEN}✓ Web App created${NC}"

# Enable HTTPS only
echo -e "\n${YELLOW}Configuring security settings...${NC}"
az webapp update \
    --name "$WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --https-only true

echo -e "${GREEN}✓ HTTPS-only enabled${NC}"

# Display summary
echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Resource Group: ${RESOURCE_GROUP}"
echo -e "App Service Plan: ${APP_SERVICE_PLAN}"
echo -e "Web App Name: ${WEB_APP_NAME}"
echo -e "Web App URL: https://${WEB_APP_NAME}.azurewebsites.net"
echo -e "${GREEN}============================================${NC}"
