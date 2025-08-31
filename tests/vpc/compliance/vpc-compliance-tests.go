// VPC Module Compliance Tests
// Tests for regulatory compliance and security standards

package vpc

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
)

// TestVPC-COMP-001: CIS AWS Foundations Benchmark 3.1
func TestCISBenchmark31(t *testing.T) {
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

	// CIS 3.1: Ensure that VPCs have corresponding flow logs
	flowLogs := aws.GetVpcFlowLogs(t, vpcId, "us-east-1")
	assert.NotEmpty(t, flowLogs, "CIS 3.1: VPC must have flow logs enabled")

	// Verify flow logs are configured correctly
	for _, flowLog := range flowLogs {
		assert.Equal(t, "ACTIVE", *flowLog.FlowLogStatus,
			"CIS 3.1: Flow logs must be active")
		assert.NotEmpty(t, flowLog.LogDestination,
			"CIS 3.1: Flow logs must have a destination")
	}
}

// TestVPC-COMP-002: NIST Cybersecurity Framework PR.AC-5
func TestNISTCSFPRAC5(t *testing.T) {
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

	// NIST PR.AC-5: Network access to network interfaces should be restricted
	subnets := aws.GetSubnetsByVpcId(t, vpcId, "us-east-1")

	for _, subnet := range subnets {
		// Verify subnet has network ACL
		assert.NotEmpty(t, subnet.NetworkAclId,
			"NIST PR.AC-5: All subnets must have network ACLs")

		// Get network ACL and verify it has restrictive rules
		nacl := aws.GetNetworkAclById(t, *subnet.NetworkAclId, "us-east-1")

		// Should have rules that restrict access
		assert.NotEmpty(t, nacl.Entries,
			"NIST PR.AC-5: Network ACL must have access control rules")

		// Check for overly permissive rules
		for _, entry := range nacl.Entries {
			if entry.IpRanges != nil {
				for _, ipRange := range entry.IpRanges {
					if *ipRange.CidrIp == "0.0.0.0/0" && *entry.RuleAction == "allow" {
						// This is acceptable for public subnets on specific ports
						// but should be flagged for review
						if entry.FromPort != nil &&
							(*entry.FromPort == 80 || *entry.FromPort == 443) {
							t.Logf("REVIEW: Public access allowed to port %d in subnet %s",
								*entry.FromPort, *subnet.SubnetId)
						}
					}
				}
			}
		}
	}
}

// TestVPC-COMP-003: ISO 27001 A.13.1.1
func TestISO27001A1311(t *testing.T) {
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

	// ISO 27001 A.13.1.1: Network controls for information transfer
	vpc := aws.GetVpcById(t, vpcId, "us-east-1")

	// Verify VPC has proper identification and classification
	assert.Contains(t, getTagValue(vpc.Tags, "Project"), "aegis-kubernetes-framework",
		"ISO 27001 A.13.1.1: Resources must be properly identified")
	assert.Contains(t, getTagValue(vpc.Tags, "Environment"), "test",
		"ISO 27001 A.13.1.1: Resources must have environment classification")

	// Verify network segmentation
	publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnets := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	assert.NotEmpty(t, publicSubnets, "ISO 27001 A.13.1.1: Public subnets required for DMZ")
	assert.NotEmpty(t, privateSubnets, "ISO 27001 A.13.1.1: Private subnets required for internal resources")

	// Verify subnets are in different availability zones for redundancy
	publicSubnetDetails := aws.GetSubnetsByIds(t, publicSubnets, "us-east-1")
	azMap := make(map[string]bool)
	for _, subnet := range publicSubnetDetails {
		azMap[*subnet.AvailabilityZone] = true
	}
	assert.Greater(t, len(azMap), 1,
		"ISO 27001 A.13.1.1: Resources should be distributed across multiple AZs")
}

// TestVPC-COMP-004: SOC 2 CC6.1
func TestSOC2CC61(t *testing.T) {
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

	// SOC 2 CC6.1: Logical access security
	securityGroups := aws.GetSecurityGroupsByVpcId(t, vpcId, "us-east-1")

	// Verify security groups exist and have restrictive rules
	assert.NotEmpty(t, securityGroups, "SOC 2 CC6.1: Security groups must exist")

	for _, sg := range securityGroups {
		// Each security group should have some rules (not completely open)
		totalRules := len(sg.IpPermissions) + len(sg.IpPermissionsEgress)
		assert.Greater(t, totalRules, 0,
			"SOC 2 CC6.1: Security group %s must have access control rules", *sg.GroupId)

		// Check for overly permissive ingress rules
		for _, permission := range sg.IpPermissions {
			if permission.IpRanges != nil {
				for _, ipRange := range permission.IpRanges {
					if *ipRange.CidrIp == "0.0.0.0/0" {
						// Log for review - may be acceptable for specific use cases
						t.Logf("REVIEW: Security group %s allows unrestricted access",
							*sg.GroupId)
					}
				}
			}
		}
	}

	// Verify network ACLs provide additional layer of access control
	subnets := aws.GetSubnetsByVpcId(t, vpcId, "us-east-1")
	for _, subnet := range subnets {
		assert.NotEmpty(t, subnet.NetworkAclId,
			"SOC 2 CC6.1: All subnets must have network ACL protection")
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