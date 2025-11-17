variable "create_manifests" {
  type        = bool
  description = "Whether to create Kubernetes manifests"
  default     = true
}

variable "argocd_name" {
  description = "Name for ArgoCD Helm release"
  type        = string
  default     = "argocd"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.6.12"
}

variable "eks_cluster_name" {
  description = "EKS cluster name for dependency"
  type        = string
}
