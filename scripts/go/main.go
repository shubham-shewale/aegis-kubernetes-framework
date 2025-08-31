package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

type Config struct {
	Environment     string
	Region          string
	ClusterName     string
	StateBucket     string
	VpcCidr         string
	PublicSubnets   []string
	PrivateSubnets  []string
}

var rootCmd = &cobra.Command{
	Use:   "aegis",
	Short: "Aegis Kubernetes Framework CLI",
	Long:  `CLI tool for provisioning and managing secure Kubernetes clusters on AWS`,
}

var provisionCmd = &cobra.Command{
	Use:   "provision",
	Short: "Provision infrastructure and cluster",
	Run: func(cmd *cobra.Command, args []string) {
		config := loadConfig()
		provisionInfrastructure(config)
		provisionCluster(config)
	},
}

var destroyCmd = &cobra.Command{
	Use:   "destroy",
	Short: "Destroy cluster and infrastructure",
	Run: func(cmd *cobra.Command, args []string) {
		config := loadConfig()
		destroyCluster(config)
		destroyInfrastructure(config)
	},
}

func init() {
	rootCmd.AddCommand(provisionCmd)
	rootCmd.AddCommand(destroyCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func loadConfig() Config {
	return Config{
		Environment:    getEnvOrDefault("AEGIS_ENVIRONMENT", "staging"),
		Region:         getEnvOrDefault("AWS_REGION", "us-east-1"),
		ClusterName:    getEnvOrDefault("CLUSTER_NAME", "staging.cluster.aegis.local"),
		StateBucket:    getEnvOrDefault("KOPS_STATE_BUCKET", ""),
		VpcCidr:        getEnvOrDefault("VPC_CIDR", "10.0.0.0/16"),
		PublicSubnets:  []string{"10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"},
		PrivateSubnets: []string{"10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"},
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func provisionInfrastructure(config Config) {
	fmt.Println("Provisioning infrastructure with Terraform...")

	cmd := exec.Command("terraform", "init")
	cmd.Dir = "../../terraform"
	runCommand(cmd)

	cmd = exec.Command("terraform", "apply", "-auto-approve",
		fmt.Sprintf("-var=environment=%s", config.Environment),
		fmt.Sprintf("-var=region=%s", config.Region),
		fmt.Sprintf("-var=state_bucket=%s", config.StateBucket))
	cmd.Dir = "../../terraform"
	runCommand(cmd)
}

func provisionCluster(config Config) {
	fmt.Println("Provisioning Kubernetes cluster with kops...")

	// Generate cluster config from template
	generateClusterConfig(config)

	// Create cluster
	cmd := exec.Command("kops", "create", "-f", "cluster.yaml")
	cmd.Dir = "../../kops"
	runCommand(cmd)

	cmd = exec.Command("kops", "create", "secret", "--name", config.ClusterName, "sshpublickey", "admin", "-i", "~/.ssh/id_rsa.pub")
	runCommand(cmd)

	cmd = exec.Command("kops", "update", "cluster", "--name", config.ClusterName, "--yes")
	runCommand(cmd)

	fmt.Println("Waiting for cluster to be ready...")
	cmd = exec.Command("kops", "validate", "cluster", "--name", config.ClusterName, "--wait", "10m")
	runCommand(cmd)
}

func destroyCluster(config Config) {
	fmt.Println("Destroying Kubernetes cluster...")

	cmd := exec.Command("kops", "delete", "cluster", "--name", config.ClusterName, "--yes")
	runCommand(cmd)
}

func destroyInfrastructure(config Config) {
	fmt.Println("Destroying infrastructure...")

	cmd := exec.Command("terraform", "destroy", "-auto-approve")
	cmd.Dir = "../../terraform"
	runCommand(cmd)
}

func generateClusterConfig(config Config) {
	templatePath := "templates/cluster.yaml.template"
	outputPath := "cluster.yaml"

	template, err := os.ReadFile(templatePath)
	if err != nil {
		log.Fatal(err)
	}

	content := string(template)
	content = strings.ReplaceAll(content, "{{CLUSTER_NAME}}", config.ClusterName)
	content = strings.ReplaceAll(content, "{{KOPS_STATE_BUCKET}}", config.StateBucket)
	content = strings.ReplaceAll(content, "{{ENVIRONMENT}}", config.Environment)
	content = strings.ReplaceAll(content, "{{REGION}}", config.Region)
	content = strings.ReplaceAll(content, "{{VPC_CIDR}}", config.VpcCidr)
	content = strings.ReplaceAll(content, "{{PUBLIC_SUBNET_1}}", config.PublicSubnets[0])
	content = strings.ReplaceAll(content, "{{PUBLIC_SUBNET_2}}", config.PublicSubnets[1])
	content = strings.ReplaceAll(content, "{{PUBLIC_SUBNET_3}}", config.PublicSubnets[2])
	content = strings.ReplaceAll(content, "{{PRIVATE_SUBNET_1}}", config.PrivateSubnets[0])
	content = strings.ReplaceAll(content, "{{PRIVATE_SUBNET_2}}", config.PrivateSubnets[1])
	content = strings.ReplaceAll(content, "{{PRIVATE_SUBNET_3}}", config.PrivateSubnets[2])

	err = os.WriteFile(outputPath, []byte(content), 0644)
	if err != nil {
		log.Fatal(err)
	}
}

func runCommand(cmd *exec.Cmd) {
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("Command failed: %v", err)
	}
}