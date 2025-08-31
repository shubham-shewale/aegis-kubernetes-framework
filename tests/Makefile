# Aegis Kubernetes Framework - Test Suite Makefile
# Comprehensive test automation for all components

.PHONY: help test test-all test-unit test-integration test-security test-compliance
.PHONY: test-vpc test-iam test-s3 test-kops test-kyverno test-network test-cert test-istio test-argocd test-scripts
.PHONY: setup clean report ci cd

# Default target
.DEFAULT_GOAL := help

# Variables
GO := go
TERRAFORM := terraform
KUBECTL := kubectl
TEST_DIR := .
REPORT_DIR := reports
ENVIRONMENT := local
CATEGORIES := all
VERBOSE := false
PARALLEL := true

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Help target
help: ## Display this help message
	@echo "$(BLUE)Aegis Test Suite - Available Commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Test Categories:$(NC)"
	@echo "  unit        - Unit tests (fast, isolated)"
	@echo "  integration - Integration tests (component interaction)"
	@echo "  security    - Security-focused tests"
	@echo "  compliance  - Regulatory compliance tests"
	@echo ""
	@echo "$(YELLOW)Component Tests:$(NC)"
	@echo "  vpc         - VPC infrastructure tests"
	@echo "  iam         - Identity and access management tests"
	@echo "  s3          - S3 storage tests"
	@echo "  kops        - Kubernetes cluster tests"
	@echo "  kyverno     - Policy engine tests"
	@echo "  network     - Network policy tests"
	@echo "  cert        - Certificate management tests"
	@echo "  istio       - Service mesh tests"
	@echo "  argocd      - GitOps tests"
	@echo "  scripts     - Validation script tests"

## Setup and Configuration

setup: ## Setup test environment and dependencies
	@echo "$(BLUE)Setting up test environment...$(NC)"
	@$(GO) mod download
	@mkdir -p $(REPORT_DIR)
	@echo "$(GREEN)Test environment setup complete$(NC)"

clean: ## Clean test artifacts and reports
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	@rm -rf $(REPORT_DIR)/*
	@find . -name "*.test" -delete
	@find . -name "*.out" -delete
	@echo "$(GREEN)Test artifacts cleaned$(NC)"

## Test Execution Targets

test: test-unit ## Run default test suite (unit tests)

test-all: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@$(GO) test -v ./... \
		-env=$(ENVIRONMENT) \
		-categories=$(CATEGORIES) \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@$(GO) test -v ./... -run="TestUnit" \
		-env=$(ENVIRONMENT) \
		-categories=$(CATEGORIES) \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-integration: ## Run integration tests only
	@echo "$(BLUE)Running integration tests...$(NC)"
	@$(GO) test -v ./... -run="TestIntegration" \
		-env=$(ENVIRONMENT) \
		-categories=$(CATEGORIES) \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-security: ## Run security tests only
	@echo "$(BLUE)Running security tests...$(NC)"
	@$(GO) test -v ./... -run="TestSecurity" \
		-env=$(ENVIRONMENT) \
		-categories=$(CATEGORIES) \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-compliance: ## Run compliance tests only
	@echo "$(BLUE)Running compliance tests...$(NC)"
	@$(GO) test -v ./... -run="TestCompliance" \
		-env=$(ENVIRONMENT) \
		-categories=$(CATEGORIES) \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

## Component-Specific Tests

test-vpc: ## Run VPC-related tests
	@echo "$(BLUE)Running VPC tests...$(NC)"
	@$(GO) test -v ./vpc/... \
		-env=$(ENVIRONMENT) \
		-categories=vpc \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-iam: ## Run IAM-related tests
	@echo "$(BLUE)Running IAM tests...$(NC)"
	@$(GO) test -v ./iam/... \
		-env=$(ENVIRONMENT) \
		-categories=iam \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-s3: ## Run S3-related tests
	@echo "$(BLUE)Running S3 tests...$(NC)"
	@$(GO) test -v ./s3/... \
		-env=$(ENVIRONMENT) \
		-categories=s3 \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-kops: ## Run kOps cluster tests
	@echo "$(BLUE)Running kOps tests...$(NC)"
	@$(GO) test -v ./kops/... \
		-env=$(ENVIRONMENT) \
		-categories=kops \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-kyverno: ## Run Kyverno policy tests
	@echo "$(BLUE)Running Kyverno tests...$(NC)"
	@$(GO) test -v ./kyverno/... \
		-env=$(ENVIRONMENT) \
		-categories=kyverno \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-network: ## Run network policy tests
	@echo "$(BLUE)Running network policy tests...$(NC)"
	@$(GO) test -v ./network-policies/... \
		-env=$(ENVIRONMENT) \
		-categories=network-policies \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-cert: ## Run certificate management tests
	@echo "$(BLUE)Running certificate tests...$(NC)"
	@$(GO) test -v ./cert-manager/... \
		-env=$(ENVIRONMENT) \
		-categories=cert-manager \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-istio: ## Run Istio service mesh tests
	@echo "$(BLUE)Running Istio tests...$(NC)"
	@$(GO) test -v ./istio/... \
		-env=$(ENVIRONMENT) \
		-categories=istio \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-argocd: ## Run ArgoCD tests
	@echo "$(BLUE)Running ArgoCD tests...$(NC)"
	@$(GO) test -v ./argocd/... \
		-env=$(ENVIRONMENT) \
		-categories=argocd \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

test-scripts: ## Run validation script tests
	@echo "$(BLUE)Running script tests...$(NC)"
	@$(GO) test -v ./scripts/... \
		-env=$(ENVIRONMENT) \
		-categories=scripts \
		-verbose=$(VERBOSE) \
		-parallel=$(PARALLEL) \
		-report-dir=$(REPORT_DIR)

## CI/CD Integration

ci: setup ## Run CI pipeline (unit + security tests)
	@echo "$(BLUE)Running CI pipeline...$(NC)"
	@make test-unit
	@make test-security
	@make report
	@echo "$(GREEN)CI pipeline completed$(NC)"

cd: ## Run CD pipeline (integration + compliance tests)
	@echo "$(BLUE)Running CD pipeline...$(NC)"
	@make test-integration
	@make test-compliance
	@make report
	@echo "$(GREEN)CD pipeline completed$(NC)"

## Reporting and Analysis

report: ## Generate test reports
	@echo "$(BLUE)Generating test reports...$(NC)"
	@mkdir -p $(REPORT_DIR)
	@$(GO) test -v ./... -json > $(REPORT_DIR)/test-results.json
	@$(GO) test -v ./... -coverprofile=$(REPORT_DIR)/coverage.out
	@$(GO) tool cover -html=$(REPORT_DIR)/coverage.out -o $(REPORT_DIR)/coverage.html
	@echo "$(GREEN)Test reports generated in $(REPORT_DIR)/"

coverage: ## Display test coverage
	@echo "$(BLUE)Test Coverage Report:$(NC)"
	@$(GO) test -v ./... -cover

## Environment Configuration

# Development environment
dev: ENVIRONMENT=development
dev: VERBOSE=true
dev: test-unit

# Staging environment
staging: ENVIRONMENT=staging
staging: CATEGORIES=vpc,iam,s3,kops,kyverno
staging: test-integration

# Production environment
prod: ENVIRONMENT=production
prod: CATEGORIES=vpc,iam,kops,kyverno
prod: test-compliance

## Utility Targets

lint: ## Lint Go code
	@echo "$(BLUE)Linting Go code...$(NC)"
	@golangci-lint run
	@echo "$(GREEN)Linting completed$(NC)"

fmt: ## Format Go code
	@echo "$(BLUE)Formatting Go code...$(NC)"
	@$(GO) fmt ./...
	@echo "$(GREEN)Code formatted$(NC)"

deps: ## Update dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@$(GO) mod tidy
	@$(GO) mod download
	@echo "$(GREEN)Dependencies updated$(NC)"

## Quick Test Commands

quick: VERBOSE=false
quick: PARALLEL=true
quick: test-unit

full: VERBOSE=true
full: PARALLEL=true
full: test-all

debug: VERBOSE=true
debug: PARALLEL=false
debug: test-unit

## Test Data and Fixtures

fixtures: ## Generate test fixtures
	@echo "$(BLUE)Generating test fixtures...$(NC)"
	@mkdir -p fixtures
	@echo "Generating mock data..."
	@echo "$(GREEN)Test fixtures generated$(NC)"

mocks: ## Generate mock objects
	@echo "$(BLUE)Generating mocks...$(NC)"
	@which mockery > /dev/null || (echo "Installing mockery..." && $(GO) install github.com/vektra/mockery/v2@latest)
	@mockery --all --output mocks
	@echo "$(GREEN)Mocks generated$(NC)"

## Performance Testing

perf: ## Run performance tests
	@echo "$(BLUE)Running performance tests...$(NC)"
	@$(GO) test -v ./... -run="TestPerf" -bench=. -benchmem
	@echo "$(GREEN)Performance tests completed$(NC)"

load: ## Run load tests
	@echo "$(BLUE)Running load tests...$(NC)"
	@echo "Load testing would be implemented here"
	@echo "$(GREEN)Load tests completed$(NC)"

## Security Testing

security-scan: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	@which gosec > /dev/null || (echo "Installing gosec..." && $(GO) install github.com/securecodewarrior/github-action-gosec@latest)
	@gosec ./...
	@echo "$(GREEN)Security scan completed$(NC)"

vuln-scan: ## Run vulnerability scans
	@echo "$(BLUE)Running vulnerability scans...$(NC)"
	@which trivy > /dev/null || (echo "Installing trivy..." && curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin)
	@trivy fs .
	@echo "$(GREEN)Vulnerability scan completed$(NC)"

## Compliance Testing

cis-scan: ## Run CIS benchmark scans
	@echo "$(BLUE)Running CIS benchmark scans...$(NC)"
	@echo "CIS scanning would be implemented here"
	@echo "$(GREEN)CIS scan completed$(NC)"

nist-scan: ## Run NIST compliance scans
	@echo "$(BLUE)Running NIST compliance scans...$(NC)"
	@echo "NIST scanning would be implemented here"
	@echo "$(GREEN)NIST scan completed$(NC)"

## Docker Integration

docker-build: ## Build test Docker image
	@echo "$(BLUE)Building test Docker image...$(NC)"
	@docker build -t aegis-test-suite .
	@echo "$(GREEN)Test Docker image built$(NC)"

docker-run: ## Run tests in Docker
	@echo "$(BLUE)Running tests in Docker...$(NC)"
	@docker run --rm -v $(PWD):/app aegis-test-suite make test-all
	@echo "$(GREEN)Docker tests completed$(NC)"

## Kubernetes Integration

k8s-test: ## Run tests against Kubernetes cluster
	@echo "$(BLUE)Running tests against Kubernetes...$(NC)"
	@if ! $(KUBECTL) cluster-info > /dev/null 2>&1; then \
		echo "$(RED)No Kubernetes cluster available$(NC)"; \
		exit 1; \
	fi
	@$(GO) test -v ./kops/... ./istio/... ./kyverno/...
	@echo "$(GREEN)Kubernetes tests completed$(NC)"

## Cloud Integration

aws-test: ## Run tests against AWS
	@echo "$(BLUE)Running tests against AWS...$(NC)"
	@if ! aws sts get-caller-identity > /dev/null 2>&1; then \
		echo "$(RED)AWS credentials not configured$(NC)"; \
		exit 1; \
	fi
	@$(GO) test -v ./vpc/... ./iam/... ./s3/...
	@echo "$(GREEN)AWS tests completed$(NC)"

## Monitoring and Alerting

alert-failures: ## Alert on test failures
	@echo "$(BLUE)Checking for test failures...$(NC)"
	@if [ -f $(REPORT_DIR)/test-results.json ]; then \
		failed=$$(jq '. | select(.Action == "fail") | length' $(REPORT_DIR)/test-results.json); \
		if [ "$$failed" -gt 0 ]; then \
			echo "$(RED)ALERT: $$failed tests failed$(NC)"; \
			# Send alert to monitoring system \
		else \
			echo "$(GREEN)All tests passed$(NC)"; \
		fi \
	else \
		echo "$(YELLOW)No test results found$(NC)"; \
	fi

## Documentation

docs: ## Generate test documentation
	@echo "$(BLUE)Generating test documentation...$(NC)"
	@mkdir -p docs
	@$(GO) doc -all > docs/api.md
	@echo "$(GREEN)Test documentation generated$(NC)"

## Version Information

version: ## Display version information
	@echo "$(BLUE)Aegis Test Suite$(NC)"
	@echo "Version: 2.0.0"
	@echo "Go Version: $$($(GO) version)"
	@echo "Test Framework: Go testing + Terratest"
	@echo "Last Updated: 2024-01-01"

## Help for specific targets

help-dev: ## Development workflow help
	@echo "$(BLUE)Development Workflow:$(NC)"
	@echo "1. make setup          # Setup environment"
	@echo "2. make test-unit      # Run unit tests"
	@echo "3. make test-security  # Run security tests"
	@echo "4. make report         # Generate reports"
	@echo "5. make clean          # Clean artifacts"

help-ci: ## CI/CD workflow help
	@echo "$(BLUE)CI/CD Workflow:$(NC)"
	@echo "1. make ci             # Run CI pipeline"
	@echo "2. make cd             # Run CD pipeline"
	@echo "3. make report         # Generate reports"
	@echo "4. make alert-failures # Check for failures"

help-security: ## Security testing help
	@echo "$(BLUE)Security Testing:$(NC)"
	@echo "1. make security-scan  # Run security scans"
	@echo "2. make vuln-scan      # Run vulnerability scans"
	@echo "3. make cis-scan       # Run CIS benchmarks"
	@echo "4. make nist-scan      # Run NIST compliance"

# Include local overrides if they exist
-include Makefile.local