provider "aws" {
  region = var.region
}

data "aws_eks_cluster_auth" "this" {
  count = var.create_manifests ? 1 : 0
  name  = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = var.create_manifests ? module.eks.cluster_endpoint : null
  cluster_ca_certificate = var.create_manifests ? base64decode(module.eks.cluster_certificate_authority_data) : null
  token                  = var.create_manifests ? data.aws_eks_cluster_auth.this[0].token : null
}

provider "helm" {
  kubernetes = {
    host                   = var.create_manifests ? module.eks.cluster_endpoint : ""
    cluster_ca_certificate = var.create_manifests ? base64decode(module.eks.cluster_certificate_authority_data) : ""
    token                  = var.create_manifests ? data.aws_eks_cluster_auth.this[0].token : ""
  }
}