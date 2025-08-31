// VPC Module Integration Tests
// Tests for VPC creation, subnet connectivity, and cross-component interactions

package vpc

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestVPC-INT-001: Test VPC creation with all subnets and gateways
func TestVPCCreation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../terraform/modules/vpc",
		Vars: map[string]interface{}{
			"vpc_cidr":           "10.0.0.0/16",
			"availability_zones": []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			"public_subnets":     []string{"10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"},
			"private_subnets":    []string{"10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"},
			"environment":        "test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC creation
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcId)

	// Verify VPC exists in AWS
	vpc := aws.GetVpcById(t, vpcId, "us-east-1")
	assert.Equal(t, "10.0.0.0/16", *vpc.CidrBlock)
	assert.Equal(t, "test-aegis-vpc", getTagValue(vpc.Tags, "Name"))
}

// TestVPC-INT-002: Validate NAT gateway functionality
func TestNATGatewayFunctionality(t *testing.T) {
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

	// Get NAT gateway IDs
	natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	assert.Len(t, natGatewayIds, 2)

	// Verify NAT gateways exist and are available
	for _, natId := range natGatewayIds {
		nat := aws.GetNatGateway(t, natId, "us-east-1")
		assert.Equal(t, "available", *nat.State)
	}
}

// TestVPC-INT-003: Test cross-subnet communication
func TestCrossSubnetCommunication(t *testing.T) {
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

	// Get subnet IDs
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	// Verify all subnets are in the same VPC
	for _, subnetId := range append(publicSubnetIds, privateSubnetIds...) {
		subnet := aws.GetSubnetById(t, subnetId, "us-east-1")
		assert.Equal(t, vpcId, *subnet.VpcId)
	}

	// Verify subnets are in different availability zones
	publicSubnets := aws.GetSubnetsByVpcId(t, vpcId, "us-east-1")
	assert.Len(t, publicSubnets, 2)

	azSet := make(map[string]bool)
	for _, subnet := range publicSubnets {
		azSet[*subnet.AvailabilityZone] = true
	}
	assert.Len(t, azSet, 2, "Subnets should be in different availability zones")
}

// TestVPC-INT-004: Validate route table associations
func TestRouteTableAssociations(t *testing.T) {
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

	// Get route tables
	routeTables := aws.GetRouteTablesByVpcId(t, vpcId, "us-east-1")

	// Should have at least 3 route tables (1 public, 2 private)
	assert.GreaterOrEqual(t, len(routeTables), 3)

	// Verify route table configurations
	for _, rt := range routeTables {
		assert.NotEmpty(t, rt.Routes)

		// Check for default route (0.0.0.0/0)
		hasDefaultRoute := false
		for _, route := range rt.Routes {
			if route.DestinationCidrBlock != nil && *route.DestinationCidrBlock == "0.0.0.0/0" {
				hasDefaultRoute = true
				break
			}
		}
		assert.True(t, hasDefaultRoute, "Route table should have default route")
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