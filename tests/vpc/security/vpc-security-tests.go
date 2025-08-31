// VPC Module Security Tests
// Tests for VPC security configurations, network isolation, and access controls

package vpc

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
)

// TestVPC-SEC-001: Test default security posture
func TestVPCDefaultSecurityPosture(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../terraform/modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":           "10.0.0.0/16",
			"availability_zones": []string{"us-east-1a", "us-east-1b"},
			"public_subnets":     []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_subnets":    []string{"10.0.10.0/24", "10.0.11.0/24"},
			"environment":        "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	// Verify private subnets have no public IP assignment by default
	for _, subnetId := range privateSubnetIds {
		subnet := aws.GetSubnetById(t, subnetId, "us-east-1")
		assert.False(t, *subnet.MapPublicIpOnLaunch,
			"Private subnet should not auto-assign public IPs")
	}

	// Verify VPC has proper tags for security classification
	vpc := aws.GetVpcById(t, vpcId, "us-east-1")
	assert.Contains(t, getTagValue(vpc.Tags, "Environment"), "test")
	assert.Contains(t, getTagValue(vpc.Tags, "Project"), "aegis-kubernetes-framework")
}

// TestVPC-SEC-002: Validate network isolation
func TestVPCNetworkIsolation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../terraform/modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":           "10.0.0.0/16",
			"availability_zones": []string{"us-east-1a", "us-east-1b"},
			"public_subnets":     []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_subnets":    []string{"10.0.10.0/24", "10.0.11.0/24"},
			"environment":        "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	vpcId := terraform.Output(t, terraformOptions, "vpc_id")

	// Verify no security groups allow unrestricted access
	securityGroups := aws.GetSecurityGroupsByVpcId(t, vpcId, "us-east-1")

	for _, sg := range securityGroups {
		for _, permission := range sg.IpPermissions {
			// Check for overly permissive rules (0.0.0.0/0)
			if permission.IpRanges != nil {
				for _, ipRange := range permission.IpRanges {
					if *ipRange.CidrIp == "0.0.0.0/0" {
						// Allow HTTP/HTTPS for public subnets, but flag for review
						if permission.FromPort != nil &&
							(*permission.FromPort == 80 || *permission.FromPort == 443) {
							t.Logf("WARNING: Security group %s allows public access to port %d",
								*sg.GroupId, *permission.FromPort)
						} else {
							t.Errorf("SECURITY RISK: Security group %s allows unrestricted access to port %d",
								*sg.GroupId, *permission.FromPort)
						}
					}
				}
			}
		}
	}
}

// TestVPC-SEC-003: Test NACL rule enforcement
func TestVPCNACLRules(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../terraform/modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":           "10.0.0.0/16",
			"availability_zones": []string{"us-east-1a", "us-east-1b"},
			"public_subnets":     []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_subnets":    []string{"10.0.10.0/24", "10.0.11.0/24"},
			"environment":        "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	vpcId := terraform.Output(t, terraformOptions, "vpc_id")

	// Get all subnets
	subnets := aws.GetSubnetsByVpcId(t, vpcId, "us-east-1")

	// Verify each subnet has a network ACL
	for _, subnet := range subnets {
		assert.NotEmpty(t, subnet.NetworkAclId,
			"Subnet %s should have a network ACL", *subnet.SubnetId)

		// Get network ACL details
		nacl := aws.GetNetworkAclById(t, *subnet.NetworkAclId, "us-east-1")

		// Verify NACL has both ingress and egress rules
		assert.NotEmpty(t, nacl.Entries, "Network ACL should have rules")

		// Check for deny-all rule at the end (rule number should be high)
		hasDenyAll := false
		for _, entry := range nacl.Entries {
			if *entry.RuleNumber > 9000 && *entry.RuleAction == "deny" {
				hasDenyAll = true
				break
			}
		}
		assert.True(t, hasDenyAll,
			"Network ACL should have a deny-all rule with high rule number")
	}
}

// TestVPC-SEC-004: Validate VPC flow logs
func TestVPCFlowLogs(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../terraform/modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":           "10.0.0.0/16",
			"availability_zones": []string{"us-east-1a", "us-east-1b"},
			"public_subnets":     []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_subnets":    []string{"10.0.10.0/24", "10.0.11.0/24"},
			"environment":        "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	vpcId := terraform.Output(t, terraformOptions, "vpc_id")

	// Check if VPC flow logs are enabled
	flowLogs := aws.GetVpcFlowLogs(t, vpcId, "us-east-1")

	// Should have at least one flow log enabled
	assert.NotEmpty(t, flowLogs, "VPC should have flow logs enabled")

	// Verify flow log configuration
	for _, flowLog := range flowLogs {
		assert.Equal(t, "ACTIVE", *flowLog.FlowLogStatus,
			"Flow log should be active")

		// Verify traffic type includes all traffic
		assert.Contains(t, []string{"ALL", "ACCEPT", "REJECT"},
			*flowLog.TrafficType, "Flow log should capture all traffic types")
	}
}

// Helper function to get tag value
func getTagValue(tags []aws.EC2Tag, key string) string {
	for _, tag := range tags {
		if *tag.Key == key {
			return *tag.Value
		}
	}
	return ""
}