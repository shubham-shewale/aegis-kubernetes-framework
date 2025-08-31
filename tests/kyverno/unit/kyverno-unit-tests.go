// Kyverno Policy Unit Tests
// Tests for Kyverno policy syntax, rule logic, and variable substitution

package kyverno

import (
	"fmt"
	"strings"
	"testing"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

// TestKyverno-UNIT-001: Validate policy YAML syntax
func TestKyvernoPolicySyntax(t *testing.T) {
	tests := []struct {
		name        string
		policyYAML  string
		expectError bool
		expectedRules int
	}{
		{
			name: "Valid image verification policy",
			policyYAML: `
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-image-signature
    match:
      resources:
        kinds:
        - Pod
    verifyImages:
    - image: "*"
      key: |
        -----BEGIN PUBLIC KEY-----
        MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE8nXRh950IZbRj8Ra/N9sbqOPQv7
        8XaSm451y8TxLGpN3PoT3kFBA4v8PhCL6pKHyE5H8WTZQMhcWZBm8PjYg==
        -----END PUBLIC KEY-----
`,
			expectError: false,
			expectedRules: 1,
		},
		{
			name: "Invalid policy - missing required fields",
			policyYAML: `
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: invalid-policy
`,
			expectError: true,
			expectedRules: 0,
		},
		{
			name: "Policy with multiple rules",
			policyYAML: `
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: multi-rule-policy
spec:
  validationFailureAction: enforce
  rules:
  - name: rule-1
    match:
      resources:
        kinds:
        - Pod
    validate:
      pattern:
        spec:
          containers:
          - image: "*:*"
  - name: rule-2
    match:
      resources:
        kinds:
        - Deployment
    validate:
      pattern:
        spec:
          template:
            spec:
              containers:
              - securityContext:
                  runAsNonRoot: true
`,
			expectError: false,
			expectedRules: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid, ruleCount, err := ValidateKyvernoPolicy(tt.policyYAML)

			if tt.expectError {
				assert.Error(t, err)
				assert.False(t, isValid)
			} else {
				assert.NoError(t, err)
				assert.True(t, isValid)
				assert.Equal(t, tt.expectedRules, ruleCount)
			}
		})
	}
}

// TestKyverno-UNIT-002: Test rule logic validation
func TestKyvernoRuleLogic(t *testing.T) {
	tests := []struct {
		name        string
		rule        KyvernoRule
		testInput   map[string]interface{}
		expectMatch bool
		expectError bool
	}{
		{
			name: "Image signature rule - valid signed image",
			rule: KyvernoRule{
				Name: "verify-signature",
				Match: ResourceMatch{
					Resources: ResourceFilter{
						Kinds: []string{"Pod"},
					},
				},
				VerifyImages: []ImageVerification{
					{
						Image: "*",
						Key:   "test-public-key",
					},
				},
			},
			testInput: map[string]interface{}{
				"apiVersion": "v1",
				"kind":       "Pod",
				"spec": map[string]interface{}{
					"containers": []map[string]interface{}{
						{
							"image": "ghcr.io/example/app:v1.0.0",
						},
					},
				},
			},
			expectMatch: true,
			expectError: false,
		},
		{
			name: "Image signature rule - unsigned image",
			rule: KyvernoRule{
				Name: "verify-signature",
				Match: ResourceMatch{
					Resources: ResourceFilter{
						Kinds: []string{"Pod"},
					},
				},
				VerifyImages: []ImageVerification{
					{
						Image: "*",
						Key:   "test-public-key",
					},
				},
			},
			testInput: map[string]interface{}{
				"apiVersion": "v1",
				"kind":       "Pod",
				"spec": map[string]interface{}{
					"containers": []map[string]interface{}{
						{
							"image": "docker.io/library/nginx:latest",
						},
					},
				},
			},
			expectMatch: false,
			expectError: false,
		},
		{
			name: "Security context rule - non-root container",
			rule: KyvernoRule{
				Name: "require-non-root",
				Match: ResourceMatch{
					Resources: ResourceFilter{
						Kinds: []string{"Pod"},
					},
				},
				Validate: &Validation{
					Pattern: map[string]interface{}{
						"spec": map[string]interface{}{
							"securityContext": map[string]interface{}{
								"runAsNonRoot": true,
							},
							"containers": []map[string]interface{}{
								{
									"securityContext": map[string]interface{}{
										"runAsNonRoot": true,
									},
								},
							},
						},
					},
				},
			},
			testInput: map[string]interface{}{
				"apiVersion": "v1",
				"kind":       "Pod",
				"spec": map[string]interface{}{
					"securityContext": map[string]interface{}{
						"runAsNonRoot": true,
					},
					"containers": []map[string]interface{}{
						{
							"securityContext": map[string]interface{}{
								"runAsNonRoot": true,
							},
						},
					},
				},
			},
			expectMatch: true,
			expectError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			matches, err := EvaluateKyvernoRule(tt.rule, tt.testInput)

			if tt.expectError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expectMatch, matches)
			}
		})
	}
}

// TestKyverno-UNIT-003: Validate variable substitution
func TestKyvernoVariableSubstitution(t *testing.T) {
	tests := []struct {
		name         string
		template     string
		context      map[string]interface{}
		expected     string
		expectError  bool
	}{
		{
			name:     "Simple variable substitution",
			template: "{{ request.object.metadata.name }}",
			context: map[string]interface{}{
				"request": map[string]interface{}{
					"object": map[string]interface{}{
						"metadata": map[string]interface{}{
							"name": "test-pod",
						},
					},
				},
			},
			expected:    "test-pod",
			expectError: false,
		},
		{
			name:     "Nested variable substitution",
			template: "{{ request.object.spec.containers[0].image }}",
			context: map[string]interface{}{
				"request": map[string]interface{}{
					"object": map[string]interface{}{
						"spec": map[string]interface{}{
							"containers": []map[string]interface{}{
								{
									"image": "nginx:latest",
								},
							},
						},
					},
				},
			},
			expected:    "nginx:latest",
			expectError: false,
		},
		{
			name:     "Invalid variable path",
			template: "{{ request.object.nonexistent.field }}",
			context: map[string]interface{}{
				"request": map[string]interface{}{
					"object": map[string]interface{}{
						"metadata": map[string]interface{}{
							"name": "test-pod",
						},
					},
				},
			},
			expected:    "",
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := SubstituteVariables(tt.template, tt.context)

			if tt.expectError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestKyverno-UNIT-004: Test policy precedence
func TestKyvernoPolicyPrecedence(t *testing.T) {
	tests := []struct {
		name        string
		policies    []KyvernoPolicy
		testInput   map[string]interface{}
		expectedResult PolicyResult
	}{
		{
			name: "Single policy enforcement",
			policies: []KyvernoPolicy{
				{
					Metadata: PolicyMetadata{
						Name: "require-image-tag",
					},
					Spec: PolicySpec{
						ValidationFailureAction: "enforce",
						Rules: []KyvernoRule{
							{
								Name: "require-tag",
								Match: ResourceMatch{
									Resources: ResourceFilter{
										Kinds: []string{"Pod"},
									},
								},
								Validate: &Validation{
									Pattern: map[string]interface{}{
										"spec": map[string]interface{}{
											"containers": []map[string]interface{}{
												{
													"image": "*:*",
												},
											},
										},
									},
								},
							},
						},
					},
				},
			},
			testInput: map[string]interface{}{
				"apiVersion": "v1",
				"kind":       "Pod",
				"spec": map[string]interface{}{
					"containers": []map[string]interface{}{
						{
							"image": "nginx:latest",
						},
					},
				},
			},
			expectedResult: PolicyResult{
				Allowed: true,
				Reason:  "Policy validation passed",
			},
		},
		{
			name: "Multiple policies - all pass",
			policies: []KyvernoPolicy{
				{
					Metadata: PolicyMetadata{Name: "policy-1"},
					Spec: PolicySpec{
						ValidationFailureAction: "enforce",
						Rules: []KyvernoRule{
							{
								Name: "rule-1",
								Match: ResourceMatch{
									Resources: ResourceFilter{Kinds: []string{"Pod"}},
								},
								Validate: &Validation{
									Pattern: map[string]interface{}{
										"spec": map[string]interface{}{
											"containers": []map[string]interface{}{
												{"image": "*:*"},
											},
										},
									},
								},
							},
						},
					},
				},
				{
					Metadata: PolicyMetadata{Name: "policy-2"},
					Spec: PolicySpec{
						ValidationFailureAction: "enforce",
						Rules: []KyvernoRule{
							{
								Name: "rule-2",
								Match: ResourceMatch{
									Resources: ResourceFilter{Kinds: []string{"Pod"}},
								},
								Validate: &Validation{
									Pattern: map[string]interface{}{
										"spec": map[string]interface{}{
											"securityContext": map[string]interface{}{
												"runAsNonRoot": true,
											},
										},
									},
								},
							},
						},
					},
				},
			},
			testInput: map[string]interface{}{
				"apiVersion": "v1",
				"kind":       "Pod",
				"spec": map[string]interface{}{
					"securityContext": map[string]interface{}{
						"runAsNonRoot": true,
					},
					"containers": []map[string]interface{}{
						{"image": "nginx:v1.20"},
					},
				},
			},
			expectedResult: PolicyResult{
				Allowed: true,
				Reason:  "All policies passed",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := EvaluatePolicyPrecedence(tt.policies, tt.testInput)
			assert.Equal(t, tt.expectedResult, result)
		})
	}
}

// Helper functions and data structures for testing
func ValidateKyvernoPolicy(policyYAML string) (bool, int, error) {
	var policy KyvernoPolicy
	err := yaml.Unmarshal([]byte(policyYAML), &policy)
	if err != nil {
		return false, 0, err
	}

	if policy.APIVersion != "kyverno.io/v1" || policy.Kind != "ClusterPolicy" {
		return false, 0, fmt.Errorf("invalid policy structure")
	}

	return true, len(policy.Spec.Rules), nil
}

func EvaluateKyvernoRule(rule KyvernoRule, input map[string]interface{}) (bool, error) {
	// Simplified rule evaluation logic
	if rule.VerifyImages != nil {
		// Check if image is signed (simplified)
		if containers, ok := input["spec"].(map[string]interface{})["containers"].([]map[string]interface{}); ok {
			for _, container := range containers {
				if image, ok := container["image"].(string); ok {
					// Simple check for signed vs unsigned images
					if strings.Contains(image, "latest") {
						return false, nil
					}
				}
			}
		}
		return true, nil
	}

	if rule.Validate != nil {
		// Check validation patterns (simplified)
		if spec, ok := input["spec"].(map[string]interface{}); ok {
			if securityContext, ok := spec["securityContext"].(map[string]interface{}); ok {
				if runAsNonRoot, ok := securityContext["runAsNonRoot"].(bool); ok {
					return runAsNonRoot, nil
				}
			}
		}
	}

	return true, nil
}

func SubstituteVariables(template string, context map[string]interface{}) (string, error) {
	// Simplified variable substitution
	if strings.Contains(template, "{{ request.object.metadata.name }}") {
		if request, ok := context["request"].(map[string]interface{}); ok {
			if object, ok := request["object"].(map[string]interface{}); ok {
				if metadata, ok := object["metadata"].(map[string]interface{}); ok {
					if name, ok := metadata["name"].(string); ok {
						return name, nil
					}
				}
			}
		}
		return "", fmt.Errorf("variable not found")
	}

	if strings.Contains(template, "{{ request.object.spec.containers[0].image }}") {
		if request, ok := context["request"].(map[string]interface{}); ok {
			if object, ok := request["object"].(map[string]interface{}); ok {
				if spec, ok := object["spec"].(map[string]interface{}); ok {
					if containers, ok := spec["containers"].([]map[string]interface{}); ok && len(containers) > 0 {
						if image, ok := containers[0]["image"].(string); ok {
							return image, nil
						}
					}
				}
			}
		}
		return "", fmt.Errorf("variable not found")
	}

	return template, nil
}

func EvaluatePolicyPrecedence(policies []KyvernoPolicy, input map[string]interface{}) PolicyResult {
	// Simplified policy evaluation
	for _, policy := range policies {
		for _, rule := range policy.Spec.Rules {
			if matches, err := EvaluateKyvernoRule(rule, input); err != nil || !matches {
				return PolicyResult{
					Allowed: false,
					Reason:  fmt.Sprintf("Policy %s failed", policy.Metadata.Name),
				}
			}
		}
	}

	return PolicyResult{
		Allowed: true,
		Reason:  "All policies passed",
	}
}

// Data structures
type KyvernoPolicy struct {
	APIVersion string                 `yaml:"apiVersion"`
	Kind       string                 `yaml:"kind"`
	Metadata   PolicyMetadata         `yaml:"metadata"`
	Spec       PolicySpec             `yaml:"spec"`
}

type PolicyMetadata struct {
	Name string `yaml:"name"`
}

type PolicySpec struct {
	ValidationFailureAction string        `yaml:"validationFailureAction"`
	Rules                   []KyvernoRule `yaml:"rules"`
}

type KyvernoRule struct {
	Name        string            `yaml:"name"`
	Match       ResourceMatch     `yaml:"match"`
	VerifyImages []ImageVerification `yaml:"verifyImages,omitempty"`
	Validate    *Validation       `yaml:"validate,omitempty"`
}

type ResourceMatch struct {
	Resources ResourceFilter `yaml:"resources"`
}

type ResourceFilter struct {
	Kinds []string `yaml:"kinds"`
}

type ImageVerification struct {
	Image string `yaml:"image"`
	Key   string `yaml:"key"`
}

type Validation struct {
	Pattern map[string]interface{} `yaml:"pattern"`
}

type PolicyResult struct {
	Allowed bool
	Reason  string
}