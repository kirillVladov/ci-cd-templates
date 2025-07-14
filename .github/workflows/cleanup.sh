#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
RELEASE_NAME="nod-web"
NAMESPACE="nod-web"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --release NAME       Release name [default: nod-web]"
    echo "  -n, --namespace NAME     Namespace [default: nod-web]"
    echo "  -a, --all               Remove all releases in namespace"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Remove default release"
    echo "  $0 -r my-release         # Remove specific release"
    echo "  $0 -a                    # Remove all releases in namespace"
}

# Parse command line arguments
REMOVE_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -a|--all)
            REMOVE_ALL=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}🧹 Starting cleanup...${NC}"
echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "  Release: ${YELLOW}$RELEASE_NAME${NC}"
echo -e "  Namespace: ${YELLOW}$NAMESPACE${NC}"
echo -e "  Remove all: ${YELLOW}$REMOVE_ALL${NC}"

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed. Please install Helm first.${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

if [ "$REMOVE_ALL" = true ]; then
    echo -e "${YELLOW}🗑️  Removing all releases in namespace $NAMESPACE...${NC}"
    
    # Get all releases in namespace
    RELEASES=$(helm list -n $NAMESPACE -q)
    
    if [ -z "$RELEASES" ]; then
        echo -e "${GREEN}✅ No releases found in namespace $NAMESPACE${NC}"
    else
        for release in $RELEASES; do
            echo -e "${YELLOW}🗑️  Removing release: $release${NC}"
            helm uninstall $release -n $NAMESPACE
        done
    fi
    
    # Remove namespace
    echo -e "${YELLOW}🗑️  Removing namespace $NAMESPACE...${NC}"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    
    echo -e "${GREEN}✅ Cleanup completed!${NC}"
else
    echo -e "${YELLOW}🗑️  Removing release $RELEASE_NAME from namespace $NAMESPACE...${NC}"
    
    # Check if release exists
    if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        helm uninstall $RELEASE_NAME -n $NAMESPACE
        echo -e "${GREEN}✅ Release $RELEASE_NAME removed successfully!${NC}"
    else
        echo -e "${YELLOW}⚠️  Release $RELEASE_NAME not found in namespace $NAMESPACE${NC}"
    fi
    
    # Ask if user wants to remove namespace too
    read -p "Do you want to remove the namespace $NAMESPACE as well? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Removing namespace $NAMESPACE...${NC}"
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        echo -e "${GREEN}✅ Namespace $NAMESPACE removed!${NC}"
    fi
fi 