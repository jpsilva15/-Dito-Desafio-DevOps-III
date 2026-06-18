environment = "production"
region      = "us-east-1"
vpc_cidr    = "10.1.0.0/16"

single_nat_gateway = false

rds_instance_class          = "db.t4g.small"
rds_multi_az                = true
rds_backup_retention_period = 7
rds_deletion_protection     = true

eks_node_instance_types = ["t3.large", "t3a.large", "t3.xlarge", "t3a.xlarge"]
eks_node_min_size       = 2
eks_node_max_size       = 6
eks_node_desired_size   = 2
