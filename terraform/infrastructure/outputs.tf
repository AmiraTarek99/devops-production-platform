output "vpc_id"              { value = module.vpc.vpc_id }
output "eks_cluster_name"    { value = module.eks.cluster_name }
output "eks_cluster_endpoint"{ 
    value = module.eks.cluster_endpoint
    sensitive = true 
 }
output "ecr_backend_url"     { value = module.ecr.backend_url }
output "ecr_frontend_url"    { value = module.ecr.frontend_url }
output "rds_endpoint"        { 
    value = module.rds.endpoint
 sensitive = true 
 }

output "s3_bucket"           { value = aws_s3_bucket.app.bucket }
