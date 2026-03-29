# ── IAM Role for EKS Control Plane ──────────────────────────────────
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ── EKS Cluster ──────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = [
    "api", "audit", "authenticator",
    "controllerManager", "scheduler"
  ]

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ── IAM Role for Worker Nodes ────────────────────────────────────────
resource "aws_iam_role" "node_group" {
  name = "${var.project_name}-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ])
  policy_arn = each.value
  role       = aws_iam_role.node_group.name
}

# ── Managed Node Group ───────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnets
  instance_types  = var.node_group_config.instance_types
  capacity_type   = var.node_group_config.capacity_type

  scaling_config {
    min_size     = var.node_group_config.min_size
    max_size     = var.node_group_config.max_size
    desired_size = var.node_group_config.desired_size
  }

  update_config { max_unavailable = 1 }
  depends_on = [aws_iam_role_policy_attachment.node_policies]
}

# ── EKS Managed Add-ons ──────────────────────────────────────────────
resource "aws_eks_addon" "coredns"    { cluster_name = aws_eks_cluster.main.name; addon_name = "coredns";           depends_on = [aws_eks_node_group.main] }
resource "aws_eks_addon" "kube_proxy" { cluster_name = aws_eks_cluster.main.name; addon_name = "kube-proxy" }
resource "aws_eks_addon" "vpc_cni"    { cluster_name = aws_eks_cluster.main.name; addon_name = "vpc-cni" }
resource "aws_eks_addon" "ebs_csi"    { cluster_name = aws_eks_cluster.main.name; addon_name = "aws-ebs-csi-driver"; depends_on = [aws_eks_node_group.main] }

output "cluster_name"     { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
