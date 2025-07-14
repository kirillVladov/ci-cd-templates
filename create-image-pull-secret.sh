#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔐 Setting up GitHub Container Registry image pull secret...${NC}"

# Check if required environment variables are set
if [ -z "$GH_TOKEN" ]; then
    echo -e "${RED}❌ GITHUB_TOKEN environment variable is not set${NC}"
    echo -e "${BLUE}Please set your GitHub Personal Access Token:${NC}"
    echo -e "export GITHUB_TOKEN=your_github_token_here"
    exit 1
fi

if [ -z "$GH_USERNAME" ]; then
    echo -e "${RED}❌ GITHUB_USERNAME environment variable is not set${NC}"
    echo -e "${BLUE}Please set your GitHub username:${NC}"
    echo -e "export GITHUB_USERNAME=your_github_username"
    exit 1
fi

# Get namespace from command line or use default
NAMESPACE="${1:-nod-web}"

# Create the secret with proper labels to prevent Helm from deleting it
echo -e "${YELLOW}📦 Creating image pull secret in namespace: $NAMESPACE${NC}"

kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=$GH_USERNAME \
    --docker-password=$GH_TOKEN \
    --docker-email=kirillovvlad8@gmail.com \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | \
kubectl apply -f -

# Add labels to prevent Helm from managing this secret
echo -e "${YELLOW}🏷️  Adding labels to prevent Helm from deleting the secret...${NC}"
kubectl label secret ghcr-secret -n $NAMESPACE \
    "app.kubernetes.io/managed-by=external" \
    "helm.sh/resource-policy=keep" \
    --overwrite

echo -e "${GREEN}✅ Image pull secret created successfully!${NC}"
echo -e "${BLUE}Secret details:${NC}"
kubectl get secret ghcr-secret -n $NAMESPACE -o yaml | grep -E "(name:|type:|labels:)" || echo "Secret not found"

echo -e "${YELLOW}📋 Next steps:${NC}"
echo -e "1. The secret is now protected from Helm deletion"
echo -e "2. You can now deploy your application"
echo -e "3. The secret will persist across Helm deployments" 