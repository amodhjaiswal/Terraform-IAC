###########----------VPC---------###########
module "vpc" {
  source                = "./modules/vpc"
  env_name              = terraform.workspace
  project_name          = var.project_name
  tags                  = var.tags
  vpc_name              = var.vpc_name
  cidr_block            = var.cidr_block
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
  region                = var.region
}

###########----------VPC-CLEANUP---------###########
module "vpc_cleanup" {
  source   = "./modules/vpc-cleanup"
  region   = var.region
  vpc_cidr = var.cidr_block
  
  depends_on = [module.vpc]
}

###########----------EC2-BASTION---------###########
module "ec2-bastion" {
  source              = "./modules/ec2-bastion"
  env_name            = terraform.workspace
  project_name        = var.project_name
  region              = var.region
  tags                = var.tags
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = var.cidr_block
  public_subnet       = module.vpc.public_subnet_ids[0]
  ami_id              = var.ami_id
  instance_type       = var.instance_type
  instance_name       = var.instance_name
  bastion_ebs_size    = var.bastion_ebs_size
}

# ###########----------REDIS---------###########
# module "elastic-cache-redis" {
#   source                  = "./modules/elastic_cache"
#   env_name                = terraform.workspace
#   project_name            = var.project_name
#   tags                    = var.tags
#   vpc_id                  = module.vpc.vpc_id
#   vpc_cidr                = var.cidr_block
#   private_subnet_ids      = module.vpc.private_subnet_ids
#   node_type               = var.node_type
#   engine_version          = var.engine_version
#   engine_version_major    = var.engine_version_major
# }

# ###########----------S3-WITH-CF---------###########
# module "frontend-s3-cf" {
#   source                   = "./modules/frontend_s3_cf"
#   env_name                 = terraform.workspace
#   project_name             = var.project_name
#   tags                     = var.tags
#   frontend_bucket_name     = var.frontend_bucket_name

# }

###########----------Media-S3-WITH-CF---------###########
module "media-s3-cf" {
  source               = "./modules/media_s3_cf"
  env_name             = terraform.workspace
  project_name         = var.project_name
  tags                 = var.tags
  media_bucket_name    = var.media_bucket_name

}

###########----------SECRET-MANAGER---------###########

module "secret-manager" {
  source        = "./modules/secret_manager"
  env_name      = terraform.workspace
  project_name  = var.project_name
  tags          = var.tags

}


###########----------ECR---------###########

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  env_name     = var.env_name
  tags         = var.tags
}


###########----------EKS---------###########

module "eks" {
  source                  = "./modules/eks/eks_cluster"
  env_name                = terraform.workspace
  project_name            = var.project_name
  tags                    = var.tags
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  cluster_version         = var.cluster_version
  node_instance_type      = var.node_instance_type
  node_min_size           = var.node_min_size
  node_desired_size       = var.node_desired_size
  node_max_size           = var.node_max_size
  codebuild_role_arn      = module.codepipeline-global.codebuild_role_arn
  bastion_ssm_role_arn    = module.ec2-bastion.bastion_ssm_role_arn
  bastion_sg_id           = module.ec2-bastion.bastion_sg_id
  region                  = var.region
  secret_arn              = module.secret-manager.secret_arn
  bucket_name             = module.media-s3-cf.bucket_name
  

}

###########----------EKS-SERVICE-ACCOUNT---------###########

module "eks_serviceaccount" {
  source = "./modules/eks/eks_serviceaccount"
  count  = var.create_manifests ? 1 : 0

  cluster_name         = module.eks.cluster_name
  region              = var.region
  namespace           = terraform.workspace
  service_account_name = "${var.project_name}-${terraform.workspace}-service-account"
  role_arn            = module.eks.pod_identity_role_arn
  project_name        = var.project_name
  environment         = terraform.workspace

  providers = {
    kubernetes = kubernetes
    aws        = aws
  }

  depends_on = [module.eks]
}

###########----------EKS-AWS-INGRESS-CONTROLLER---------###########

module "eks_aws_lb_controller" {
  source = "./modules/eks/eks_aws_lb_controller"
  create_manifests  = var.create_manifests
  project_name      = var.project_name
  env_name          = terraform.workspace
  cluster_name      = module.eks.cluster_name
  vpc_id            = module.vpc.vpc_id
  region            = var.region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_url          = module.eks.oidc_url
  node_group_status = module.eks.node_group_status
  tags              = var.tags
  depends_on = [
    module.eks
  ]
}

###########----------EKS-ARGOCD---------###########

module "eks_argocd" {
  source = "./modules/eks/eks_argocd"
  create_manifests = var.create_manifests
  eks_cluster_name = module.eks.cluster_name
  providers = {
    helm = helm
    kubernetes = kubernetes
  }
  depends_on = [
    module.eks,
    module.eks_aws_lb_controller
  ]
}

###########----------KUBERNETES-MANIFESTS---------###########

module "eks_manifest" {
  source = "./modules/eks/eks_manifest"

  eks_cluster_name    = module.eks.cluster_name
  public_subnet_ids   = module.vpc.public_subnet_ids
  aws_lb_controller   = module.eks_aws_lb_controller
  argocd_deployment   = module.eks_argocd
  vpc_id              = module.vpc.vpc_id
  region              = var.region
  create_manifests    = var.create_manifests
  project_name        = var.project_name
  env_name            = var.env_name
  domain              = var.domain

  providers = {
    kubernetes = kubernetes
  }

  depends_on = [
    module.eks,
    module.eks_aws_lb_controller,
    module.eks_argocd
  ]
}


###########----------CODEPIPELINE-GLOBAL---------###########

module "codepipeline-global" {
  source            = "./modules/codepipeline_global"
  env_name          = terraform.workspace
  project_name      = var.project_name
  tags              = var.tags
}

# ###########----------CODEPIPELINE-BACKEND-EKS---------###########

# module "codepipeline-backend-eks" {
#   source                   = "./modules//eks/eks_codepipeline"
#   env_name                 = terraform.workspace
#   project_name             = var.project_name
#   region                   = var.region
#   tags                     = var.tags
#   eks_cluster_name         = module.eks.cluster_name
#   aws_account_id           = var.aws_account_id
#   for_each                 = local.pipelines
#   service_name             = each.value.service_name
#   artifact_bucket_name     = module.codepipeline-global.artifact_bucket_name
#   codepipeline_role_arn    = module.codepipeline-global.codepipeline_role_arn
#   codebuild_role_arn       = module.codepipeline-global.codebuild_role_arn

# }


###########----------ECS-CLUSTER---------###########

# module "ecs" {
#   source        = "./modules/ecs/ecs_cluster"
#   env_name      = terraform.workspace
#   project_name  = var.project_name
#   tags          = var.tags
# }

# ################-----ECS-Load-Balancer-----################

# module "ecs-loadbalancer" {
# source         = "./modules/ecs/ecs_loadbalancer"
# project_name   = var.project_name
# env_name       = var.env_name
# tags           = var.tags
# vpc_id         = module.vpc.vpc_id
# public_subnets = module.vpc.public_subnet_ids
# for_each       = local.ecs_pipelines
# port           = each.value.port
# service_name   = each.value.service_name
# }


# ################----ECS-Task-Service--------################

# module "ecs_task_service" {
# source             = "./modules/ecs/ecs_task"
# project_name       = var.project_name
# env_name           = var.env_name
# region             = var.region
# tags               = var.tags
# ecs_cluster_id     = module.ecs.ecs_cluster_id
# execution_role_arn = module.ecs.ecs_task_execution_role_arn
# task_role_arn      = module.ecs.ecs_task_role_arn
# vpc_id             = module.vpc.vpc_id
# alb_sg_id          = module.ecs-loadbalancer[each.key].alb_sg_id
# private_subnets    = module.vpc.private_subnet_ids
# ecr_repository_url = module.ecr.ecr_repository_url
# target_group_arn   = module.ecs-loadbalancer[each.key].target_group_arn
# for_each           = local.ecs_pipelines
# port               = each.value.port
# service_name       = each.value.service_name
# ecs_cpu            = var.ecs_cpu
# ecs_memory         = var.ecs_memory
# ecs_task_count     = var.ecs_task_count

# }

###########----------MONITORING-GRAFANA---------###########

module "eks_grafana" {
  source = "./modules/eks/eks_grafana"

  create_monitoring        = var.create_monitoring
  project_name            = var.project_name
  env_name                = terraform.workspace
  cluster_name            = module.eks.cluster_name
  region                  = var.region
  account_id              = var.aws_account_id
  oidc_provider_arn       = module.eks.oidc_provider_arn
  oidc_provider_url       = module.eks.oidc_url
  grafana_admin_password  = var.grafana_admin_password
  loki_retention_period   = var.loki_retention_period
  loki_storage_size       = var.loki_storage_size
  prometheus_storage_size = var.prometheus_storage_size
  grafana_storage_size    = var.grafana_storage_size
  promtail_storage_size   = var.promtail_storage_size
  enable_metrics_server   = var.enable_metrics_server
  metrics_server_chart_version = var.metrics_server_chart_version
  eks_cluster_endpoint    = module.eks.cluster_endpoint

  providers = {
    aws        = aws
    kubernetes = kubernetes
    helm       = helm
  }

  depends_on = [
    module.eks,
    module.eks_aws_lb_controller
  ]
}

# ################---------ECS-CODEPIPELINE------################

# module "codepipeline-ecs" {
#   source = "./modules/ecs/ecs_codepipeline"
#   env_name              = terraform.workspace
#   project_name          = var.project_name
#   region                = var.region
#   tags                  = var.tags
#   aws_account_id        = var.aws_account_id
#   for_each              = local.ecs_pipelines
#   service_name          = each.value.service_name
#   port                  = each.value.port
#   artifact_bucket_name  = module.codepipeline-global.artifact_bucket_name
#   codepipeline_role_arn = module.codepipeline-global.codepipeline_role_arn
#   codebuild_role_arn    = module.codepipeline-global.codebuild_role_arn
#   ecr_repository_url    = module.ecr.ecr_repository_url
# }