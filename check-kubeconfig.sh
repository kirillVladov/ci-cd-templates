#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Kubernetes Cluster Configuration Checker${NC}"
echo "=========================================="

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ kubectl is installed${NC}"

# Check current context
echo -e "\n${BLUE}📋 Current kubectl configuration:${NC}"
kubectl config current-context 2>/dev/null || echo -e "${RED}No current context${NC}"

# Check if we can connect to cluster
echo -e "\n${BLUE}🔗 Testing cluster connection:${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✅ Successfully connected to cluster${NC}"
    kubectl cluster-info
else
    echo -e "${RED}❌ Failed to connect to cluster${NC}"
fi

# Show current config
echo -e "\n${BLUE}📄 Current kubectl config:${NC}"
kubectl config view --minify

# Check if KUBECONFIG is set
echo -e "\n${BLUE}🔧 Environment variables:${NC}"
echo "KUBECONFIG: ${KUBECONFIG:-'not set'}"
echo "KUBE_CONFIG: ${KUBE_CONFIG:-'not set'}"

# If KUBE_CONFIG is set, try to decode it
if [ ! -z "$KUBE_CONFIG" ]; then
    echo -e "\n${BLUE}🔓 Decoding KUBE_CONFIG:${NC}"
    echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig_decoded
    echo "Decoded kubeconfig size: $(wc -c < /tmp/kubeconfig_decoded) bytes"
    echo "First 200 chars of decoded config:"
    head -c 200 /tmp/kubeconfig_decoded
    echo ""
    
    # Test the decoded config
    export KUBECONFIG=/tmp/kubeconfig_decoded
    echo -e "\n${BLUE}🧪 Testing decoded config:${NC}"
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✅ Decoded config works!${NC}"
        kubectl config current-context
    else
        echo -e "${RED}❌ Decoded config failed${NC}"
    fi
fi

# Instructions for creating kubeconfig
echo -e "\n${YELLOW}📖 How to create kubeconfig for CI/CD:${NC}"
echo "1. Get your cluster credentials:"
echo "   kubectl config view --flatten --minify"
echo ""
echo "2. Encode to base64:"
echo "   kubectl config view --flatten --minify | base64 -w 0"
echo ""
echo "3. Add to GitHub Secrets:"
echo "   - KUBE_CONFIG_DEV (for development)"
echo "   - KUBE_CONFIG_PROD (for production)"
echo ""
echo "4. Add to GitLab Variables:"
echo "   - KUBE_CONFIG_DEV"
echo "   - KUBE_CONFIG_PROD"

# Common cluster setup commands
echo -e "\n${YELLOW}🚀 Common cluster setup commands:${NC}"
echo ""
echo "# For kind cluster:"
echo "kind create cluster --name nod-web"
echo "kind export kubeconfig --name nod-web"
echo "kubectl config view --flatten --minify | base64 -w 0"
echo ""
echo "# For minikube:"
echo "minikube start"
echo "minikube kubectl -- config view --flatten --minify | base64 -w 0"
echo ""
echo "# For GKE:"
echo "gcloud container clusters get-credentials your-cluster --region=your-region"
echo "kubectl config view --flatten --minify | base64 -w 0"
echo ""
echo "# For EKS:"
echo "aws eks update-kubeconfig --name your-cluster --region your-region"
echo "kubectl config view --flatten --minify | base64 -w 0" 