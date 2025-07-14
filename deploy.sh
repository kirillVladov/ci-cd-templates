#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory early
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${BLUE}🔍 Debug: SCRIPT_DIR resolved to: $SCRIPT_DIR${NC}"

# Default values
ENVIRONMENT="dev"
RELEASE_NAME="nod-web"
NAMESPACE="nod-web"
VALUES_FILE="values.dev.yaml"
DRY_RUN=false
SKIP_BUILD=false
FORCE=false
HELM_EXTRA_ARGS=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [-- HELM_ARGS...]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment (dev|prod) [default: dev]"
    echo "  -r, --release NAME       Release name [default: nod-web]"
    echo "  -n, --namespace NAME     Namespace [default: nod-web]"
    echo "  -f, --values FILE        Values file [default: values.dev.yaml]"
    echo "  -d, --dry-run           Dry run mode"
    echo "  -s, --skip-build        Skip Docker build (for CI/CD)"
    echo "  --force                 Force deployment by deleting conflicting namespace and letting Helm recreate it"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  IMAGE_REPOSITORY        Docker image repository"
    echo "  IMAGE_TAG              Docker image tag"
    echo "  CI_COMMIT_SHA          Git commit SHA (for CI/CD)"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev                    # Deploy to development"
    echo "  $0 -e prod                   # Deploy to production"
    echo "  $0 -e dev -d                 # Dry run for development"
    echo "  $0 -f custom-values.yaml     # Use custom values file"
    echo "  $0 -s                        # Skip build (for CI/CD)"
    echo "  $0 -e prod -- --set image.tag=v1.0.0  # With extra Helm args"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        --)
            shift
            HELM_EXTRA_ARGS="$@"
            break
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT. Use 'dev' or 'prod'.${NC}"
    exit 1
fi

# Set values file based on environment if not specified
if [[ "$VALUES_FILE" == "values.dev.yaml" && "$ENVIRONMENT" == "prod" ]]; then
    VALUES_FILE="values.prod.yaml"
fi

# Debug: Show original VALUES_FILE
echo -e "${BLUE}🔍 Debug: Original VALUES_FILE: $VALUES_FILE${NC}"

# Convert to absolute path if it's a relative path
if [[ "$VALUES_FILE" != /* ]]; then
    # Try multiple locations for the values file
    POSSIBLE_PATHS=(
        "$(pwd)/$VALUES_FILE"           # Current working directory
        "$SCRIPT_DIR/$VALUES_FILE"       # Script directory
        "$(dirname "$SCRIPT_DIR")/$VALUES_FILE"  # Parent of script directory
        "/$VALUES_FILE"                  # Root directory (fallback)
    )
    
    VALUES_FILE_FOUND=false
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$path" ]; then
            VALUES_FILE="$path"
            VALUES_FILE_FOUND=true
            echo -e "${BLUE}🔍 Debug: Found values file at: $VALUES_FILE${NC}"
            break
        fi
    done
    
    if [ "$VALUES_FILE_FOUND" = false ]; then
        echo -e "${BLUE}🔍 Debug: Values file not found in any of these locations:${NC}"
        for path in "${POSSIBLE_PATHS[@]}"; do
            echo -e "${BLUE}🔍 Debug:   - $path${NC}"
        done
    fi
fi

# Debug: Show what we're looking for
echo -e "${BLUE}🔍 Debug: Looking for values file at: $VALUES_FILE${NC}"
echo -e "${BLUE}🔍 Debug: Script directory: $SCRIPT_DIR${NC}"
echo -e "${BLUE}🔍 Debug: Current working directory: $(pwd)${NC}"
echo -e "${BLUE}🔍 Debug: Listing files in current directory:${NC}"
ls -la || echo "Cannot list current directory"
echo -e "${BLUE}🔍 Debug: Listing files in script directory:${NC}"
ls -la "$SCRIPT_DIR" || echo "Cannot list script directory"

# Verify values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}❌ Values file not found: $VALUES_FILE${NC}"
    echo -e "${YELLOW}💡 Available files in script directory:${NC}"
    ls -la "$SCRIPT_DIR" || echo "Cannot list script directory"
    exit 1
fi

echo -e "${BLUE}📁 Using values file: $VALUES_FILE${NC}"

echo -e "${GREEN}🚀 Starting NOD Web deployment with Helm...${NC}"
echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "  Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "  Release: ${YELLOW}$RELEASE_NAME${NC}"
echo -e "  Namespace: ${YELLOW}$NAMESPACE${NC}"
echo -e "  Values file: ${YELLOW}$VALUES_FILE${NC}"
echo -e "  Dry run: ${YELLOW}$DRY_RUN${NC}"
echo -e "  Skip build: ${YELLOW}$SKIP_BUILD${NC}"
echo -e "  Force: ${YELLOW}${FORCE:-false}${NC}"
if [ ! -z "$HELM_EXTRA_ARGS" ]; then
    echo -e "  Extra Helm args: ${YELLOW}$HELM_EXTRA_ARGS${NC}"
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed. Please install Helm first.${NC}"
    exit 1
fi

# Show Helm version for debugging
echo -e "${BLUE}🔍 Helm version:${NC}"
helm version --short || helm version

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if we're connected to a cluster
echo -e "${BLUE}🔍 Checking cluster connection...${NC}"
echo -e "${YELLOW}💡 Current KUBECONFIG: ${KUBECONFIG:-'not set'}${NC}"

# Check if kubeconfig file exists
if [ ! -z "$KUBECONFIG" ] && [ ! -f "$KUBECONFIG" ]; then
    echo -e "${RED}❌ KUBECONFIG file not found: $KUBECONFIG${NC}"
    exit 1
fi

# Check current context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
if [ -z "$CURRENT_CONTEXT" ]; then
    echo -e "${RED}❌ No current context found${NC}"
    echo -e "${YELLOW}💡 Available contexts:${NC}"
    kubectl config get-contexts 2>/dev/null || echo "No contexts available"
    exit 1
fi

echo -e "${GREEN}✅ Current context: $CURRENT_CONTEXT${NC}"

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to cluster${NC}"
    echo -e "${YELLOW}💡 Context: $CURRENT_CONTEXT${NC}"
    echo -e "${YELLOW}💡 KUBECONFIG: $KUBECONFIG${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connected to cluster successfully${NC}"
kubectl cluster-info

# Build Docker image (skip if in CI/CD mode)
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${YELLOW}📦 Building Docker image...${NC}"
    
    # Get the project root directory (2 levels up from k8s/helm)
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    if [ ! -f "$PROJECT_ROOT/Dockerfile" ]; then
        echo -e "${RED}❌ Dockerfile not found at: $PROJECT_ROOT/Dockerfile${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📁 Building from: $PROJECT_ROOT${NC}"
    docker build -f "$PROJECT_ROOT/Dockerfile" -t nod-web-frontend:latest "$PROJECT_ROOT"

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Docker build failed${NC}"
        exit 1
    fi

    # Load image to kind if using kind cluster
    if kubectl config current-context | grep -q "kind"; then
        echo -e "${YELLOW}📤 Loading image to kind cluster...${NC}"
        kind load docker-image nod-web-frontend:latest
    fi
else
    echo -e "${BLUE}⏭️  Skipping Docker build (CI/CD mode)${NC}"
fi

# Check if namespace exists and handle it properly
echo -e "${YELLOW}📁 Checking namespace...${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${BLUE}📁 Namespace $NAMESPACE already exists${NC}"
    
    # Check if namespace is managed by Helm
    if kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null | grep -q "Helm"; then
        echo -e "${GREEN}✅ Namespace is managed by Helm${NC}"
    else
        echo -e "${YELLOW}⚠️  Namespace exists but is not managed by Helm${NC}"
        if [ "$FORCE" = true ]; then
            echo -e "${YELLOW}💡 Force flag enabled, cleaning up existing namespace...${NC}"
            
            # First, try to delete any resources in the namespace that might prevent deletion
            echo -e "${BLUE}🧹 Cleaning up resources in namespace...${NC}"
            kubectl delete all --all -n $NAMESPACE --ignore-not-found=true
            kubectl delete pvc --all -n $NAMESPACE --ignore-not-found=true
            kubectl delete pv --all -n $NAMESPACE --ignore-not-found=true
            kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true
            # Don't delete secrets that are marked as external
            kubectl delete secret --all -n $NAMESPACE --ignore-not-found=true --field-selector=metadata.labels.app.kubernetes.io/managed-by!=external
            kubectl delete serviceaccount --all -n $NAMESPACE --ignore-not-found=true
            
            # Don't delete the namespace, just clean up resources
            echo -e "${GREEN}✅ Namespace resources cleaned up${NC}"
        else
            echo -e "${YELLOW}💡 Namespace exists but resources will be updated by Helm${NC}"
        fi
    fi
else
    echo -e "${BLUE}📁 Namespace $NAMESPACE will be created by Helm${NC}"
fi

# Let Helm manage the namespace
echo -e "${YELLOW}📁 Namespace will be managed by Helm${NC}"

# Deploy with Helm
echo -e "${YELLOW}🚀 Deploying with Helm...${NC}"

# Let Helm manage the namespace completely
echo -e "${YELLOW}📁 Namespace will be managed by Helm${NC}"

HELM_ARGS=""
if [ "$DRY_RUN" = true ]; then
    HELM_ARGS="--dry-run"
    echo -e "${BLUE}🔍 Running in dry-run mode${NC}"
fi

# Set image parameters from environment variables or defaults
IMAGE_REPO="${IMAGE_REPOSITORY:-}"
IMAGE_TAG="${IMAGE_TAG:-}"

# Build Helm command with image parameters
CHART_PATH="$SCRIPT_DIR/nod-web"

# Verify chart exists
if [ ! -d "$CHART_PATH" ]; then
    echo -e "${RED}❌ Chart directory not found: $CHART_PATH${NC}"
    exit 1
fi

if [ ! -f "$CHART_PATH/Chart.yaml" ]; then
    echo -e "${RED}❌ Chart.yaml not found in: $CHART_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}📁 Using chart path: $CHART_PATH${NC}"

# Debug: Show current directory and chart structure
echo -e "${BLUE}🔍 Debug info:${NC}"
echo -e "  Current directory: $(pwd)"
echo -e "  Script directory: $SCRIPT_DIR"
echo -e "  Chart path: $CHART_PATH"
echo -e "  Chart contents:"
ls -la "$CHART_PATH" || echo "Cannot list chart directory"

HELM_CMD="helm upgrade --install $RELEASE_NAME $CHART_PATH \
    --namespace $NAMESPACE \
    --values $VALUES_FILE \
    --create-namespace \
    --wait \
    --timeout 10m \
    $HELM_ARGS"

# Add image parameters only if explicitly provided in environment variables
if [ ! -z "$IMAGE_REPO" ] && [[ ! "$HELM_EXTRA_ARGS" =~ image\.repository ]]; then
    echo -e "${BLUE}📦 Using image repository from environment: $IMAGE_REPO${NC}"
    HELM_CMD="$HELM_CMD --set image.repository=$IMAGE_REPO"
else
    echo -e "${BLUE}📦 Using image repository from values file${NC}"
fi
if [ ! -z "$IMAGE_TAG" ] && [[ ! "$HELM_EXTRA_ARGS" =~ image\.tag ]]; then
    echo -e "${BLUE}📦 Using image tag from environment: $IMAGE_TAG${NC}"
    HELM_CMD="$HELM_CMD --set image.tag=$IMAGE_TAG"
else
    echo -e "${BLUE}📦 Using image tag from values file${NC}"
fi

# Add extra Helm arguments if provided
if [ ! -z "$HELM_EXTRA_ARGS" ]; then
    echo -e "${BLUE}📋 Adding extra Helm args: $HELM_EXTRA_ARGS${NC}"
    HELM_CMD="$HELM_CMD $HELM_EXTRA_ARGS"
fi

echo -e "${YELLOW}🔧 Final Helm command:${NC}"
echo -e "${YELLOW}$HELM_CMD${NC}"

# Validate chart before deployment
echo -e "${BLUE}🔍 Validating chart...${NC}"
helm lint "$CHART_PATH" || {
    echo -e "${RED}❌ Chart validation failed${NC}"
    exit 1
}

echo -e "${YELLOW}Executing: $HELM_CMD${NC}"

# Show namespace status before deployment
echo -e "${BLUE}📁 Checking namespace status before deployment...${NC}"
kubectl get namespace $NAMESPACE --ignore-not-found=true || echo "Namespace does not exist yet"

# Execute Helm command
echo -e "${YELLOW}🔧 Executing Helm command...${NC}"
eval $HELM_CMD
HELM_EXIT_CODE=$?

# If Helm fails, show more debugging info
if [ $HELM_EXIT_CODE -ne 0 ]; then
    echo -e "${YELLOW}🔍 Helm deployment failed. Checking for issues...${NC}"
    echo -e "${BLUE}📋 Checking namespace resources:${NC}"
    kubectl get all -n $NAMESPACE || echo "No resources found"
    echo -e "${BLUE}📋 Checking events:${NC}"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' || echo "No events found"
    echo -e "${BLUE}📋 Checking pod logs:${NC}"
    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=nod-web --tail=50 || echo "No logs found"
    echo -e "${BLUE}📋 Checking pod status:${NC}"
    kubectl get pods -n $NAMESPACE -o wide || echo "No pods found"
    echo -e "${BLUE}📋 Checking deployment status:${NC}"
    kubectl describe deployment -n $NAMESPACE $(kubectl get deployment -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null) || echo "No deployment found"
fi

if [ $HELM_EXIT_CODE -eq 0 ]; then
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}✅ Dry run completed successfully!${NC}"
    else
        echo -e "${GREEN}✅ Deployment successful!${NC}"
        echo -e "${GREEN}📊 Check status with:${NC}"
        echo -e "  kubectl get pods -n $NAMESPACE"
        echo -e "  kubectl get svc -n $NAMESPACE"
        echo -e "  helm list -n $NAMESPACE"
        
        # Show service URL if available
        SERVICE_URL=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ ! -z "$SERVICE_URL" ]; then
            echo -e "${GREEN}🌐 Service URL: http://$SERVICE_URL${NC}"
        fi
        
        # Show deployment info
        echo -e "${GREEN}📋 Deployment Info:${NC}"
        echo -e "  Image: $IMAGE_REPO:$IMAGE_TAG"
        echo -e "  Environment: $ENVIRONMENT"
        echo -e "  Namespace: $NAMESPACE"
        echo -e "  Release: $RELEASE_NAME"
    fi
else
    echo -e "${RED}❌ Deployment failed (exit code: $HELM_EXIT_CODE)${NC}"
    echo -e "${YELLOW}🔍 Checking namespace status...${NC}"
    kubectl get namespace $NAMESPACE --ignore-not-found=true || echo "Namespace not found"
    echo -e "${YELLOW}🔍 Checking Helm status...${NC}"
    helm status $RELEASE_NAME -n $NAMESPACE 2>/dev/null || echo "Release not found"
    echo -e "${YELLOW}🔍 Check logs with:${NC}"
    echo -e "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=nod-web"
    echo -e "  helm status $RELEASE_NAME -n $NAMESPACE"
    exit 1
fi 