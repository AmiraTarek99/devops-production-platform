module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

module "eks" {
  source          = "./modules/eks"
  project_name    = var.project_name
  environment     = var.environment
  cluster_version = var.eks_cluster_version
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  node_group_config = {
    min_size       = 1
    max_size       = 5
    desired_size   = 2
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
  }
}

module "rds" {
  source          = "./modules/rds"
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  db_password     = var.db_password
}


resource "aws_s3_bucket" "app" {
  bucket = "${var.project_name}-${var.environment}-storage"
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
