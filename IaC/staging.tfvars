environment = "staging"
region      = "us-east-1"
vpc_cidr    = "10.0.0.0/16"

single_nat_gateway = true

rds_instance_class          = "db.t4g.micro"
rds_multi_az                = false
rds_backup_retention_period = 1
rds_deletion_protection     = false

eks_node_instance_types = ["t3.medium", "t3a.medium", "t3.large", "t3a.large"]
eks_node_min_size       = 1
eks_node_max_size       = 3
eks_node_desired_size   = 1
