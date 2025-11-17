##################################
# AWS Provider
##################################
provider "aws" {
  region = var.region
}

##################################
# Kubernetes Provider
##################################
provider "kubernetes" {
  host                   = var.create_manifests ? module.eks.cluster_endpoint : null
  cluster_ca_certificate = var.create_manifests ? base64decode(module.eks.cluster_certificate_authority_data) : null

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = [
      "eks",
      "get-token",
      "--cluster-name",
      var.create_manifests ? module.eks.cluster_name : ""
    ]
  }
}

##################################
# Helm Provider 
##################################
provider "helm" {
  kubernetes = {
    host                   = var.create_manifests ? module.eks.cluster_endpoint : null
    cluster_ca_certificate = var.create_manifests ? base64decode(module.eks.cluster_certificate_authority_data) : null

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = [
        "eks",
        "get-token",
        "--cluster-name",
        var.create_manifests ? module.eks.cluster_name : ""
      ]
    }
  }
}
