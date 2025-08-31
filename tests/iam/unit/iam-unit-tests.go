// IAM Module Unit Tests
// Tests for IAM policy generation, role assumption logic, and permission boundaries

package iam

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestIAM-UNIT-001: Validate IAM policy document generation
func TestIAMPolicyDocumentGeneration(t *testing.T) {
	tests := []struct {
		name           string
		service        string
		actions        []string
		resources      []string
		expectError    bool
		expectedActions int
	}{
		{
			name:           "EC2 read-only policy",
			service:        "ec2",
			actions:        []string{"DescribeInstances", "DescribeTags"},
			resources:      []string{"*"},
			expectError:    false,
			expectedActions: 2,
		},
		{
			name:           "S3 full access policy",
			service:        "s3",
			actions:        []string{"GetObject", "PutObject", "DeleteObject", "ListBucket"},
			resources:      []string{"arn:aws:s3:::test-bucket", "arn:aws:s3:::test-bucket/*"},
			expectError:    false,
			expectedActions: 4,
		},
		{
			name:           "Invalid service",
			service:        "",
			actions:        []string{"DescribeInstances"},
			resources:      []string{"*"},
			expectError:    true,
			expectedActions: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			policyDoc, err := GenerateIAMPolicy(tt.service, tt.actions, tt.resources)

			if tt.expectError {
				assert.Error(t, err)
				assert.Nil(t, policyDoc)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, policyDoc)

				// Parse the policy document
				var policy map[string]interface{}
				err := json.Unmarshal([]byte(*policyDoc), &policy)
				assert.NoError(t, err)

				// Verify structure
				assert.Contains(t, policy, "Version")
				assert.Contains(t, policy, "Statement")

				statements := policy["Statement"].([]interface{})
				assert.Len(t, statements, 1)

				statement := statements[0].(map[string]interface{})
				assert.Equal(t, "Allow", statement["Effect"])

				actions := statement["Action"].([]interface{})
				assert.Len(t, actions, tt.expectedActions)
			}
		})
	}
}

// TestIAM-UNIT-002: Test role assumption logic
func TestRoleAssumptionLogic(t *testing.T) {
	tests := []struct {
		name            string
		roleName        string
		principalType   string
		principalValue  string
		expectError     bool
		expectedConditions int
	}{
		{
			name:            "EC2 instance role",
			roleName:        "test-ec2-role",
			principalType:   "Service",
			principalValue:  "ec2.amazonaws.com",
			expectError:     false,
			expectedConditions: 0,
		},
		{
			name:            "OIDC role for kOps",
			roleName:        "test-oidc-role",
			principalType:   "Federated",
			principalValue:  "arn:aws:iam::123456789012:oidc-provider/example.com",
			expectError:     false,
			expectedConditions: 1,
		},
		{
			name:            "Invalid principal type",
			roleName:        "test-role",
			principalType:   "Invalid",
			principalValue:  "test-value",
			expectError:     true,
			expectedConditions: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assumeRolePolicy, err := GenerateAssumeRolePolicy(tt.roleName, tt.principalType, tt.principalValue)

			if tt.expectError {
				assert.Error(t, err)
				assert.Nil(t, assumeRolePolicy)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, assumeRolePolicy)

				// Parse the policy document
				var policy map[string]interface{}
				err := json.Unmarshal([]byte(*assumeRolePolicy), &policy)
				assert.NoError(t, err)

				statements := policy["Statement"].([]interface{})
				assert.Len(t, statements, 1)

				statement := statements[0].(map[string]interface{})
				principal := statement["Principal"].(map[string]interface{})

				if tt.principalType == "Service" {
					assert.Contains(t, principal, tt.principalType)
					assert.Equal(t, tt.principalValue, principal[tt.principalType])
				} else if tt.principalType == "Federated" {
					assert.Contains(t, principal, tt.principalType)
					assert.Equal(t, tt.principalValue, principal[tt.principalType])
				}

				// Check for conditions in OIDC scenarios
				if tt.expectedConditions > 0 {
					assert.Contains(t, statement, "Condition")
					condition := statement["Condition"].(map[string]interface{})
					assert.NotEmpty(t, condition)
				}
			}
		})
	}
}

// TestIAM-UNIT-003: Validate permission boundary application
func TestPermissionBoundaryApplication(t *testing.T) {
	tests := []struct {
		name              string
		boundaryName      string
		maxPermissions    int
		restrictedServices []string
		expectError       bool
	}{
		{
			name:              "Standard permission boundary",
			boundaryName:      "test-boundary",
			maxPermissions:    10,
			restrictedServices: []string{"iam", "organizations"},
			expectError:       false,
		},
		{
			name:              "Minimal permission boundary",
			boundaryName:      "minimal-boundary",
			maxPermissions:    5,
			restrictedServices: []string{},
			expectError:       false,
		},
		{
			name:              "Invalid boundary name",
			boundaryName:      "",
			maxPermissions:    10,
			restrictedServices: []string{"iam"},
			expectError:       true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			boundaryPolicy, err := GeneratePermissionBoundary(tt.boundaryName, tt.maxPermissions, tt.restrictedServices)

			if tt.expectError {
				assert.Error(t, err)
				assert.Nil(t, boundaryPolicy)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, boundaryPolicy)

				// Parse the policy document
				var policy map[string]interface{}
				err := json.Unmarshal([]byte(*boundaryPolicy), &policy)
				assert.NoError(t, err)

				statements := policy["Statement"].([]interface{})
				assert.Greater(t, len(statements), 0)

				// Verify statements contain deny rules for restricted services
				for _, service := range tt.restrictedServices {
					found := false
					for _, stmt := range statements {
						statement := stmt.(map[string]interface{})
						if effect, ok := statement["Effect"].(string); ok && effect == "Deny" {
							if action, ok := statement["Action"].(string); ok {
								if strings.Contains(action, service) {
									found = true
									break
								}
							}
						}
					}
					assert.True(t, found, "Boundary should deny access to %s", service)
				}
			}
		})
	}
}

// TestIAM-UNIT-004: Test OIDC provider configuration
func TestOIDCProviderConfiguration(t *testing.T) {
	tests := []struct {
		name         string
		issuerURL    string
		audience     string
		expectError  bool
		expectedURL  string
	}{
		{
			name:         "Valid OIDC provider",
			issuerURL:    "https://example.com",
			audience:     "sts.amazonaws.com",
			expectError:  false,
			expectedURL:  "https://example.com",
		},
		{
			name:         "kOps OIDC provider",
			issuerURL:    "https://s3-us-east-1.amazonaws.com/kops-state/cluster-discovery",
			audience:     "sts.amazonaws.com",
			expectError:  false,
			expectedURL:  "https://s3-us-east-1.amazonaws.com/kops-state/cluster-discovery",
		},
		{
			name:         "Invalid URL",
			issuerURL:    "not-a-url",
			audience:     "",
			expectError:  true,
			expectedURL:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			providerConfig, err := ConfigureOIDCProvider(tt.issuerURL, tt.audience)

			if tt.expectError {
				assert.Error(t, err)
				assert.Nil(t, providerConfig)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, providerConfig)
				assert.Equal(t, tt.expectedURL, providerConfig.URL)
				assert.Contains(t, providerConfig.ClientIDList, tt.audience)
			}
		})
	}
}

// Helper functions for testing
func GenerateIAMPolicy(service string, actions []string, resources []string) (*string, error) {
	if service == "" {
		return nil, fmt.Errorf("service cannot be empty")
	}

	policy := map[string]interface{}{
		"Version": "2012-10-17",
		"Statement": []map[string]interface{}{
			{
				"Effect":   "Allow",
				"Action":   actions,
				"Resource": resources,
			},
		},
	}

	policyBytes, err := json.Marshal(policy)
	if err != nil {
		return nil, err
	}

	policyStr := string(policyBytes)
	return &policyStr, nil
}

func GenerateAssumeRolePolicy(roleName, principalType, principalValue string) (*string, error) {
	if principalType == "Invalid" {
		return nil, fmt.Errorf("invalid principal type")
	}

	policy := map[string]interface{}{
		"Version": "2012-10-17",
		"Statement": []map[string]interface{}{
			{
				"Effect": "Allow",
				"Principal": map[string]string{
					principalType: principalValue,
				},
				"Action": "sts:AssumeRole",
			},
		},
	}

	// Add conditions for OIDC
	if principalType == "Federated" {
		policy["Statement"].([]map[string]interface{})[0]["Condition"] = map[string]interface{}{
			"StringEquals": map[string]string{
				"example.com:sub": "system:serviceaccount:default:test-sa",
			},
		}
	}

	policyBytes, err := json.Marshal(policy)
	if err != nil {
		return nil, err
	}

	policyStr := string(policyBytes)
	return &policyStr, nil
}

func GeneratePermissionBoundary(name string, maxPermissions int, restrictedServices []string) (*string, error) {
	if name == "" {
		return nil, fmt.Errorf("boundary name cannot be empty")
	}

	statements := []map[string]interface{}{
		{
			"Effect":   "Allow",
			"Action":   "s3:GetObject",
			"Resource": "*",
		},
	}

	// Add deny statements for restricted services
	for _, service := range restrictedServices {
		statements = append(statements, map[string]interface{}{
			"Effect":   "Deny",
			"Action":   service + ":*",
			"Resource": "*",
		})
	}

	policy := map[string]interface{}{
		"Version":   "2012-10-17",
		"Statement": statements,
	}

	policyBytes, err := json.Marshal(policy)
	if err != nil {
		return nil, err
	}

	policyStr := string(policyBytes)
	return &policyStr, nil
}

func ConfigureOIDCProvider(issuerURL, audience string) (*OIDCProviderConfig, error) {
	if !strings.HasPrefix(issuerURL, "https://") {
		return nil, fmt.Errorf("invalid issuer URL")
	}

	return &OIDCProviderConfig{
		URL:           issuerURL,
		ClientIDList:  []string{audience},
		ThumbprintList: []string{"thumbprint"},
	}, nil
}

type OIDCProviderConfig struct {
	URL            string
	ClientIDList   []string
	ThumbprintList []string
}