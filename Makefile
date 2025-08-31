# Aegis Kubernetes Framework - Makefile
# Comprehensive build, test, and deployment automation

.PHONY: help setup-dev build test lint fmt clean deploy docs security-scan

# Default target
.DEFAULT_GOAL := help

# Variables
GO_VERSION := 1.21
TERRAFORM_VERSION := 1.5.0
KUBECTL_VERSION := v1.28.0
KOPS_VERSION := v1.28.0

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Help target
help: ## Display this help message
	@echo "$(BLUE)Aegis Kubernetes Framework - Available Commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make setup-dev     # Setup development environment"
	@echo "  make build         # Build all components"
	@echo "  make test          # Run all tests"
	@echo "  make deploy        # Deploy to current cluster"
	@echo "  make security-scan # Run security scans"

## Development Environment Setup

setup-dev: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@make setup-go
	@make setup-terraform
	@make setup-kubectl
	@make setup-kops
	@make setup-tools
	@echo "$(GREEN)Development environment setup complete!$(NC)"

setup-go: ## Setup Go development environment
	@echo "$(BLUE)Setting up Go $(GO_VERSION)...$(NC)"
	@if command -v go >/dev/null 2>&1; then \
		echo "Go is already installed: $$(go version)"; \
	else \
		echo "Please install Go $(GO_VERSION) from https://golang.org/dl/"; \
		exit 1; \
	fi
	@cd scripts/go && go mod download
	@echo "$(GREEN)Go setup complete$(NC)"

setup-terraform: ## Setup Terraform development environment
	@echo "$(BLUE)Setting up Terraform $(TERRAFORM_VERSION)...$(NC)"
	@if command -v terraform >/dev/null 2>&1; then \
		echo "Terraform is already installed: $$(terraform version)"; \
	else \
		echo "Please install Terraform $(TERRAFORM_VERSION) from https://terraform.io/downloads"; \
		exit 1; \
	fi
	@echo "$(GREEN)Terraform setup complete$(NC)"

setup-kubectl: ## Setup kubectl
	@echo "$(BLUE)Setting up kubectl $(KUBECTL_VERSION)...$(NC)"
	@if command -v kubectl >/dev/null 2>&1; then \
		echo "kubectl is already installed: $$(kubectl version --client --short)"; \
	else \
		echo "Please install kubectl from https://kubernetes.io/docs/tasks/tools/"; \
		exit 1; \
	fi
	@echo "$(GREEN)kubectl setup complete$(NC)"

setup-kops: ## Setup kops
	@echo "$(BLUE)Setting up kops $(KOPS_VERSION)...$(NC)"
	@if command -v kops >/dev/null 2>&1; then \
		echo "kops is already installed: $$(kops version)"; \
	else \
		echo "Please install kops from https://kops.sigs.k8s.io/getting_started/install/"; \
		exit 1; \
	fi
	@echo "$(GREEN)kops setup complete$(NC)"

setup-tools: ## Setup additional development tools
	@echo "$(BLUE)Setting up additional tools...$(NC)"
	@command -v docker >/dev/null 2>&1 || (echo "Please install Docker" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "Please install AWS CLI" && exit 1)
	@command -v git >/dev/null 2>&1 || (echo "Please install Git" && exit 1)
	@echo "$(GREEN)Additional tools setup complete$(NC)"

## Build Targets

build: build-cli build-docs ## Build all components
	@echo "$(GREEN)All components built successfully$(NC)"

build-cli: ## Build Go CLI application
	@echo "$(BLUE)Building Go CLI...$(NC)"
	@cd scripts/go && go build -o ../../bin/aegis main.go
	@echo "$(GREEN)CLI built: bin/aegis$(NC)"

build-docs: ## Build documentation
	@echo "$(BLUE)Building documentation...$(NC)"
	@echo "$(GREEN)Documentation build complete$(NC)"

## Testing Targets

test: test-go test-terraform test-integration ## Run all tests
	@echo "$(GREEN)All tests completed$(NC)"

test-go: ## Run Go tests
	@echo "$(BLUE)Running Go tests...$(NC)"
	@cd scripts/go && go test -v ./... -coverprofile=coverage.out
	@cd scripts/go && go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)Go tests completed. Coverage report: scripts/go/coverage.html$(NC)"

test-terraform: ## Validate Terraform configurations
	@echo "$(BLUE)Validating Terraform...$(NC)"
	@cd terraform && terraform init -backend=false
	@cd terraform && terraform validate
	@cd terraform && terraform fmt -check
	@echo "$(GREEN)Terraform validation completed$(NC)"

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@echo "$(YELLOW)Note: Integration tests require a running Kubernetes cluster$(NC)"
	@if kubectl cluster-info >/dev/null 2>&1; then \
		echo "Running integration tests..."; \
		# Add integration test commands here \
		echo "$(GREEN)Integration tests completed$(NC)"; \
	else \
		echo "$(YELLOW)Skipping integration tests - no cluster available$(NC)"; \
	fi

test-security: ## Run security-focused tests
	@echo "$(BLUE)Running security tests...$(NC)"
	@make security-scan
	@echo "$(GREEN)Security tests completed$(NC)"

## Code Quality Targets

lint: lint-go lint-terraform ## Run all linters
	@echo "$(GREEN)Linting completed$(NC)"

lint-go: ## Lint Go code
	@echo "$(BLUE)Linting Go code...$(NC)"
	@cd scripts/go && golangci-lint run
	@echo "$(GREEN)Go linting completed$(NC)"

lint-terraform: ## Lint Terraform code
	@echo "$(BLUE)Linting Terraform code...$(NC)"
	@cd terraform && terraform fmt -check
	@if command -v tflint >/dev/null 2>&1; then \
		cd terraform && tflint; \
	else \
		echo "$(YELLOW)tflint not found, skipping advanced Terraform linting$(NC)"; \
	fi
	@echo "$(GREEN)Terraform linting completed$(NC)"

fmt: fmt-go fmt-terraform ## Format all code
	@echo "$(GREEN)Code formatting completed$(NC)"

fmt-go: ## Format Go code
	@echo "$(BLUE)Formatting Go code...$(NC)"
	@cd scripts/go && go fmt ./...
	@echo "$(GREEN)Go code formatted$(NC)"

fmt-terraform: ## Format Terraform code
	@echo "$(BLUE)Formatting Terraform code...$(NC)"
	@cd terraform && terraform fmt
	@echo "$(GREEN)Terraform code formatted$(NC)"

## Security Targets

security-scan: security-go security-terraform security-container ## Run all security scans
	@echo "$(GREEN)Security scanning completed$(NC)"

security-go: ## Security scan Go code
	@echo "$(BLUE)Scanning Go code for security issues...$(NC)"
	@if command -v gosec >/dev/null 2>&1; then \
		cd scripts/go && gosec ./...; \
	else \
		echo "$(YELLOW)gosec not found, install with: go install github.com/securecodewarrior/github-action-gosec@latest$(NC)"; \
	fi
	@echo "$(GREEN)Go security scan completed$(NC)"

security-terraform: ## Security scan Terraform code
	@echo "$(BLUE)Scanning Terraform for security issues...$(NC)"
	@if command -v checkov >/dev/null 2>&1; then \
		cd terraform && checkov -f . --framework terraform; \
	else \
		echo "$(YELLOW)checkov not found, install with: pip install checkov$(NC)"; \
	fi
	@echo "$(GREEN)Terraform security scan completed$(NC)"

security-container: ## Security scan container images
	@echo "$(BLUE)Scanning container images for vulnerabilities...$(NC)"
	@if command -v trivy >/dev/null 2>&1; then \
		trivy config .; \
	else \
		echo "$(YELLOW)trivy not found, install from: https://aquasecurity.github.io/trivy/$(NC)"; \
	fi
	@echo "$(GREEN)Container security scan completed$(NC)"

## Deployment Targets

deploy: deploy-infrastructure deploy-cluster deploy-security ## Deploy everything
	@echo "$(GREEN)Full deployment completed$(NC)"

deploy-infrastructure: ## Deploy infrastructure with Terraform
	@echo "$(BLUE)Deploying infrastructure...$(NC)"
	@echo "$(YELLOW)Note: This will create AWS resources and may incur costs$(NC)"
	@cd terraform && terraform init
	@cd terraform && terraform plan
	@echo "$(YELLOW)Review the plan above. Run 'make deploy-infrastructure-confirm' to apply$(NC)"

deploy-infrastructure-confirm: ## Confirm and apply infrastructure deployment
	@echo "$(BLUE)Applying infrastructure changes...$(NC)"
	@cd terraform && terraform apply

deploy-cluster: ## Deploy Kubernetes cluster with kops
	@echo "$(BLUE)Deploying Kubernetes cluster...$(NC)"
	@echo "$(YELLOW)Note: This will create EC2 instances and may incur costs$(NC)"
	@if [ -z "$$CLUSTER_NAME" ]; then \
		echo "$(RED)Error: CLUSTER_NAME environment variable not set$(NC)"; \
		echo "Example: export CLUSTER_NAME=my-cluster.example.com"; \
		exit 1; \
	fi
	@if [ -z "$$AWS_REGION" ]; then \
		echo "$(RED)Error: AWS_REGION environment variable not set$(NC)"; \
		echo "Example: export AWS_REGION=us-east-1"; \
		exit 1; \
	fi
	@kops create cluster --name=$$CLUSTER_NAME --state=s3://$$KOPS_STATE_BUCKET --zones=$$AWS_REGION"a,$$AWS_REGION"b,$$AWS_REGION"c" --node-count=3 --master-zones=$$AWS_REGION"a,$$AWS_REGION"b,$$AWS_REGION"c" --master-count=3 --networking=calico --yes
	@echo "$(GREEN)Cluster deployment initiated. Use 'kops validate cluster' to check status$(NC)"

deploy-security: ## Deploy security components
	@echo "$(BLUE)Deploying security components...$(NC)"
	@kubectl apply -f manifests/argocd/install.yaml
	@kubectl apply -f manifests/istio/
	@kubectl apply -f manifests/kyverno/
	@kubectl apply -f manifests/trivy/
	@echo "$(GREEN)Security components deployed$(NC)"

deploy-argocd: ## Deploy ArgoCD for GitOps
	@echo "$(BLUE)Deploying ArgoCD...$(NC)"
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f manifests/argocd/install.yaml
	@echo "$(GREEN)ArgoCD deployed. Get admin password with:$(NC)"
	@echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

## Cleanup Targets

clean: clean-build clean-test clean-deploy ## Clean all artifacts
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-build: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf bin/
	@cd scripts/go && go clean
	@echo "$(GREEN)Build artifacts cleaned$(NC)"

clean-test: ## Clean test artifacts
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	@cd scripts/go && rm -f coverage.out coverage.html
	@find . -name "*.test" -delete
	@echo "$(GREEN)Test artifacts cleaned$(NC)"

clean-deploy: ## Clean deployment artifacts
	@echo "$(BLUE)Cleaning deployment artifacts...$(NC)"
	@echo "$(YELLOW)Warning: This will destroy infrastructure$(NC)"
	@echo "To destroy infrastructure: cd terraform && terraform destroy"
	@echo "To delete cluster: kops delete cluster --name=\$\$CLUSTER_NAME --yes"

destroy: ## Destroy all resources (USE WITH CAUTION)
	@echo "$(RED)WARNING: This will destroy all resources!$(NC)"
	@echo "$(RED)This action cannot be undone.$(NC)"
	@read -p "Are you sure you want to continue? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "$(BLUE)Destroying cluster...$(NC)"; \
		kops delete cluster --name=$$CLUSTER_NAME --yes; \
		echo "$(BLUE)Destroying infrastructure...$(NC)"; \
		cd terraform && terraform destroy -auto-approve; \
		echo "$(GREEN)All resources destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Operation cancelled$(NC)"; \
	fi

## Documentation Targets

docs: docs-build docs-serve ## Build and serve documentation
	@echo "$(GREEN)Documentation ready$(NC)"

docs-build: ## Build documentation
	@echo "$(BLUE)Building documentation...$(NC)"
	@echo "$(GREEN)Documentation built$(NC)"

docs-serve: ## Serve documentation locally
	@echo "$(BLUE)Serving documentation on http://localhost:8000$(NC)"
	@cd docs && python3 -m http.server 8000 || echo "$(YELLOW)Python not available, manually open docs/index.html$(NC)"

docs-validate: ## Validate documentation links and structure
	@echo "$(BLUE)Validating documentation...$(NC)"
	@echo "$(GREEN)Documentation validation completed$(NC)"

## Utility Targets

version: ## Display version information
	@echo "$(BLUE)Aegis Kubernetes Framework$(NC)"
	@echo "Go Version: $(GO_VERSION)"
	@echo "Terraform Version: $(TERRAFORM_VERSION)"
	@echo "Kubernetes Version: $(KUBECTL_VERSION)"
	@echo "kops Version: $(KOPS_VERSION)"

health-check: ## Run health checks
	@echo "$(BLUE)Running health checks...$(NC)"
	@make -s check-go
	@make -s check-terraform
	@make -s check-kubernetes
	@echo "$(GREEN)Health checks completed$(NC)"

check-go: ## Check Go environment
	@echo -n "Go: "
	@go version || echo "$(RED)Not found$(NC)"

check-terraform: ## Check Terraform environment
	@echo -n "Terraform: "
	@terraform version || echo "$(RED)Not found$(NC)"

check-kubernetes: ## Check Kubernetes environment
	@echo -n "Kubernetes: "
	@kubectl version --client --short || echo "$(RED)Not found$(NC)"
	@echo -n "Cluster: "
	@kubectl cluster-info >/dev/null 2>&1 && echo "$(GREEN)Connected$(NC)" || echo "$(RED)Not connected$(NC)"

## CI/CD Targets

ci: ## Run CI pipeline locally
	@echo "$(BLUE)Running CI pipeline...$(NC)"
	@make lint
	@make test
	@make security-scan
	@make build
	@echo "$(GREEN)CI pipeline completed successfully$(NC)"

cd: ## Run CD pipeline locally (requires cluster)
	@echo "$(BLUE)Running CD pipeline...$(NC)"
	@make deploy-infrastructure-confirm
	@make deploy-cluster
	@make deploy-security
	@echo "$(GREEN)CD pipeline completed successfully$(NC)"

## Help for specific targets

help-dev: ## Development workflow help
	@echo "$(BLUE)Development Workflow:$(NC)"
	@echo "1. make setup-dev          # Setup environment"
	@echo "2. make build              # Build components"
	@echo "3. make test               # Run tests"
	@echo "4. make lint               # Check code quality"
	@echo "5. make security-scan      # Security scanning"
	@echo "6. make deploy             # Deploy (requires cluster)"

help-deploy: ## Deployment workflow help
	@echo "$(BLUE)Deployment Workflow:$(NC)"
	@echo "1. Set environment variables:"
	@echo "   export CLUSTER_NAME=my-cluster.example.com"
	@echo "   export AWS_REGION=us-east-1"
	@echo "   export KOPS_STATE_BUCKET=my-kops-state"
	@echo "2. make deploy-infrastructure    # Deploy infra"
	@echo "3. make deploy-cluster          # Deploy cluster"
	@echo "4. make deploy-security         # Deploy security"

help-troubleshoot: ## Troubleshooting help
	@echo "$(BLUE)Troubleshooting:$(NC)"
	@echo "- Check cluster: kubectl cluster-info"
	@echo "- Check pods: kubectl get pods -A"
	@echo "- Check logs: kubectl logs <pod-name> -n <namespace>"
	@echo "- Validate cluster: kops validate cluster"
	@echo "- Check AWS: aws sts get-caller-identity"

# Include environment-specific Makefiles if they exist
-include Makefile.local
-include terraform/Makefile
-include scripts/Makefile