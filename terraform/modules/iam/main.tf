data "aws_caller_identity" "current" {}

# IAM Role for kops
resource "aws_iam_role" "kops" {
  name = "${var.environment}-kops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# Note: OIDC Provider is managed by kOps when serviceAccountIssuerDiscovery is enabled
# with enableAWSOIDCProvider: true. Terraform cannot predict the exact ARN before
# cluster creation, so this data source should be used after the cluster exists.

# Data source to get the kOps-managed OIDC provider (use after cluster creation)
# data "aws_iam_openid_connect_provider" "kops_oidc" {
#   # Uncomment and populate after kOps cluster creation
#   # arn = "arn:aws:iam::<account-id>:oidc-provider/<oidc-provider-url>"
# }

# Custom policy for kops with least privilege
resource "aws_iam_role_policy" "kops" {
  name = "${var.environment}-kops-policy"
  role = aws_iam_role.kops.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 permissions for cluster management
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:CreateKeypair",
          "ec2:DeleteKeypair",
          "ec2:ImportKeyPair",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:ModifyInstanceAttribute",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:ModifyLaunchTemplate"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
        }
      },
      # IAM permissions for instance profiles
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.environment}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.environment}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.environment}-*"
        ]
      },
      # S3 permissions for kops state
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.environment}-aegis-kops-state-*",
          "arn:aws:s3:::${var.environment}-aegis-kops-state-*/*"
        ]
      },
      # Route53 permissions for DNS management
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      # ELB permissions for load balancers
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for Kubernetes nodes
resource "aws_iam_role" "nodes" {
  name = "${var.environment}-k8s-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "nodes_ec2" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_ssm" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for nodes
resource "aws_iam_instance_profile" "nodes" {
  name = "${var.environment}-k8s-nodes-profile"
  role = aws_iam_role.nodes.name
}