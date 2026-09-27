terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ==============================================================================
# AWS Provider
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "TaskManager"
      ManagedBy   = "Terraform"
    }
  }
}

# ==============================================================================
# Availability Zones & Data Sources
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ==============================================================================
# VPC
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                      = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ==============================================================================
# Internet Gateway
# ==============================================================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# ==============================================================================
# Public Subnets
# Used for NAT Gateways and internet-facing AWS Load Balancers
# ==============================================================================

resource "aws_subnet" "public" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    4,
    count.index
  )

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name                                      = "${var.cluster_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# ==============================================================================
# Private Subnets
# Used for EKS Managed Nodes and Pods
# ==============================================================================

resource "aws_subnet" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = cidrsubnet(
    var.vpc_cidr,
    4,
    count.index + 2
  )

  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                      = "${var.cluster_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

# ==============================================================================
# Elastic IPs for NAT Gateways
# ==============================================================================

resource "aws_eip" "nat" {
  count = 2

  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

# ==============================================================================
# NAT Gateways
# One NAT Gateway per Availability Zone
# ==============================================================================

resource "aws_nat_gateway" "nat" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}

# ==============================================================================
# Public Route Table
# ==============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# ==============================================================================
# Public Route Table Associations
# ==============================================================================

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# Private Route Tables
# One private route table per Availability Zone
# ==============================================================================

resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt-${count.index + 1}"
  }
}

# ==============================================================================
# Private Route Table Associations
# ==============================================================================

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id = aws_subnet.private[count.index].id

  route_table_id = aws_route_table.private[count.index].id
}

# ==============================================================================
# EKS Cluster Control Plane IAM Role
# ==============================================================================

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

# ==============================================================================
# EKS Cluster IAM Policies
# ==============================================================================

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role = aws_iam_role.cluster.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  role = aws_iam_role.cluster.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# ==============================================================================
# EKS Cluster
# ==============================================================================

resource "aws_eks_cluster" "main" {
  name = var.cluster_name

  version = var.cluster_version

  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )

    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"

    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController
  ]

  tags = {
    Name = var.cluster_name
  }
}

# ==============================================================================
# EKS Managed Node Group IAM Role
# ==============================================================================

resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-node-role"
  }
}

# ==============================================================================
# EKS Worker Node IAM Policies
# ==============================================================================

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  role = aws_iam_role.nodes.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  role = aws_iam_role.nodes.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  role = aws_iam_role.nodes.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ==============================================================================
# EKS Managed Node Group
# ==============================================================================

resource "aws_eks_node_group" "main" {
  cluster_name = aws_eks_cluster.main.name

  node_group_name = "${var.cluster_name}-node-group"

  node_role_arn = aws_iam_role.nodes.arn

  # Nodes run only in private subnets
  subnet_ids = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = var.node_instance_types

  capacity_type = "ON_DEMAND"

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
    Name = "${var.cluster_name}-node-group"
  }
}

# ==============================================================================
# GitHub Actions OIDC TLS Certificate
# ==============================================================================

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ==============================================================================
# GitHub Actions OIDC Provider
# ==============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

# ==============================================================================
# IAM Role for GitHub Actions
# AssumeRoleWithWebIdentity
# ==============================================================================

resource "aws_iam_role" "github_actions" {
  name = "${var.cluster_name}-github-actions-role"

  description = "IAM role assumed by GitHub Actions using OIDC to deploy applications to EKS"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-github-actions-role"
  }
}

# ==============================================================================
# GitHub Actions EKS IAM Policy
# ==============================================================================

resource "aws_iam_policy" "github_actions_eks_deploy" {
  name = "${var.cluster_name}-github-actions-eks-policy"

  description = "Allows GitHub Actions to access and deploy to the EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EKSClusterAccess"
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]

        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

# ==============================================================================
# Attach EKS Policy to GitHub Actions Role
# ==============================================================================

resource "aws_iam_role_policy_attachment" "github_actions_eks" {
  role = aws_iam_role.github_actions.name

  policy_arn = aws_iam_policy.github_actions_eks_deploy.arn
}

# ==============================================================================
# EKS Access Entry for GitHub Actions
# ==============================================================================

resource "aws_eks_access_entry" "github_actions" {
  cluster_name = aws_eks_cluster.main.name

  principal_arn = aws_iam_role.github_actions.arn

  type = "STANDARD"

  depends_on = [
    aws_eks_cluster.main
  ]
}

# ==============================================================================
# EKS Access Policy Association
# Grants GitHub Actions cluster administrator permissions
# ==============================================================================

resource "aws_eks_access_policy_association" "github_actions_admin" {
  cluster_name = aws_eks_cluster.main.name

  principal_arn = aws_iam_role.github_actions.arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.github_actions
  ]
}
