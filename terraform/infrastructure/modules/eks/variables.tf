variable "project_name"     { type = string }
variable "environment"      { type = string }
variable "cluster_version"  { type = string }
variable "vpc_id"           { type = string }
variable "private_subnets"  { type = list(string) }
variable "node_group_config" {
  type = object({
    min_size       = number
    max_size       = number
    desired_size   = number
    instance_types = list(string)
    capacity_type  = string
  })
}
