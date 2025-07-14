#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Kubernetes Config Generator for CI/CD${NC}"
echo "============================================="

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    echo "Please install kubectl first:"
    echo "curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
    echo "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
    exit 1
fi

# Check if we can connect to cluster
echo -e "${BLUE}🔗 Testing cluster connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    echo "Please configure kubectl to connect to your cluster first."
    echo ""
    echo "Common commands:"
    echo "  # For kind:"
    echo "  kind export kubeconfig --name your-cluster"
    echo ""
    echo "  # For minikube:"
    echo "  minikube kubectl -- config view --flatten --minify"
    echo ""
    echo "  # For GKE:"
    echo "  gcloud container clusters get-credentials your-cluster --region=your-region"
    echo ""
    echo "  # For EKS:"
    echo "  aws eks update-kubeconfig --name your-cluster --region your-region"
    exit 1
fi

echo -e "${GREEN}✅ Connected to cluster: $(kubectl config current-context)${NC}"

# Generate kubeconfig
echo -e "\n${BLUE}📄 Generating kubeconfig for CI/CD...${NC}"
KUBECONFIG_BASE64=$(kubectl config view --flatten --minify | base64 -w 0)

if [ -z "$KUBECONFIG_BASE64" ]; then
    echo -e "${RED}❌ Failed to generate kubeconfig${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubeconfig generated successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Copy this value to your CI/CD secrets:${NC}"
echo ""
echo "$KUBECONFIG_BASE64"
echo ""
echo -e "${YELLOW}📖 Instructions:${NC}"
echo ""
echo "For GitHub Actions:"
echo "1. Go to your repository → Settings → Secrets and variables → Actions"
echo "2. Add new secret:"
echo "   - Name: KUBE_CONFIG_DEV (for development)"
echo "   - Name: KUBE_CONFIG_PROD (for production)"
echo "   - Value: (paste the base64 string above)"
echo ""
echo "For GitLab CI:"
echo "1. Go to your project → Settings → CI/CD → Variables"
echo "2. Add new variable:"
echo "   - Key: KUBE_CONFIG_DEV"
echo "   - Key: KUBE_CONFIG_PROD"
echo "   - Value: (paste the base64 string above)"
echo "   - Type: Variable"
echo "   - Environment scope: All (default)"
echo "   - Protect variable: Yes"
echo "   - Mask variable: Yes"
echo ""
echo -e "${GREEN}✅ Done! Your CI/CD should now be able to connect to the cluster.${NC}" 