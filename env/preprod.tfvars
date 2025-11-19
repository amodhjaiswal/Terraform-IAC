###########----------GLOBAL VARIABLE---------###########
env_name      = "preprod"
project_name  =  "ajaaa"
region        = "us-east-1"
aws_account_id = "581580844553"
cluster_name = "testing-preprod-eks"
create_manifests = true
domain = "appskeeper.in"

###########----------VPC---------###########

cidr_block = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]


###########----------Bastion-ec2---------###########
ami_id   = "ami-06e5a963b2dadea6f"  # Openvpn ami
instance_type = "t3.small"
instance_name = "bastion"
bastion_ebs_size = 40

###########----------ELASTIC-CACHE-REDIS---------###########

node_type = "cache.t3.medium"
engine_version = 7.1
engine_version_major = 7

###########----------frontend-s3-cf---------###########
frontend_bucket_name= "admin"

###########----------media-s3-cf---------###########
media_bucket_name = "media"

###########----------eks---------###########
cluster_version = 1.32
node_instance_type = "t3.medium"
node_min_size = 2
node_desired_size = 2
node_max_size = 2

###########----------codepipeline-backend-eks---------###########
service_name_1 = "admin"
service_name_2 = "auth"


###########----------codepipeline-backend-ecs---------###########
ecs_service_name_1 = "admin"
ecs_service_port_1 = 3000
ecs_service_name_2 = "auth"
ecs_service_port_2 = 3000
ecs_cpu = "512"
ecs_memory = "1024"
ecs_task_count = 2

###########----------MONITORING---------###########
create_monitoring = true
grafana_admin_password = "SecurePassword123!"
loki_retention_period = "8760h"
loki_storage_size = "10Gi"
prometheus_storage_size = "10Gi"
grafana_storage_size = "20Gi"
promtail_storage_size = "10Gi"
