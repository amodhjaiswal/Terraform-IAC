locals {
  role_arn = var.role_arn != null ? var.role_arn : ""
}

# Cluster readiness check
resource "null_resource" "cluster_ready" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --region ${var.region} --name ${var.cluster_name}
      kubectl get nodes --request-timeout=30s
    EOT
  }
}

# Namespace
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment" = var.environment
      "project" = var.project_name
    }
  }

  depends_on = [null_resource.cluster_ready]

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# Service Account
resource "kubernetes_service_account" "app_service_account" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    annotations = local.role_arn != "" ? {
      "eks.amazonaws.com/role-arn" = local.role_arn
    } : {}
    labels = {
      "app.kubernetes.io/name"       = var.service_account_name
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
      "project"                      = var.project_name
    }
  }

  depends_on = [kubernetes_namespace.app_namespace]

  lifecycle {
    ignore_changes = [metadata[0].annotations, metadata[0].labels]
  }
}

# Pod Identity Association
resource "aws_eks_pod_identity_association" "app_pod_identity" {
  cluster_name    = var.cluster_name
  namespace       = kubernetes_namespace.app_namespace.metadata[0].name
  service_account = kubernetes_service_account.app_service_account.metadata[0].name
  role_arn        = local.role_arn

  tags = {
    Name        = "${var.project_name}-${var.environment}-pod-identity"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  depends_on = [kubernetes_service_account.app_service_account]
}

# Cleanup resource for smooth deletion
resource "null_resource" "cleanup" {
  triggers = {
    cluster_name     = var.cluster_name
    service_account  = var.service_account_name
    namespace        = var.namespace
    region           = var.region
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      # Update kubeconfig
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true
      
      # Delete pod identity association first
      kubectl delete podidentityassociation --all -n ${self.triggers.namespace} --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
      
      # Remove finalizers from service account
      kubectl patch serviceaccount ${self.triggers.service_account} -n ${self.triggers.namespace} -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      
      # Force delete service account
      kubectl delete serviceaccount ${self.triggers.service_account} -n ${self.triggers.namespace} --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
      
      # Remove finalizers from namespace
      kubectl patch namespace ${self.triggers.namespace} -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      
      # Force delete namespace
      kubectl delete namespace ${self.triggers.namespace} --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true
    EOT
  }

  depends_on = [
    aws_eks_pod_identity_association.app_pod_identity,
    kubernetes_service_account.app_service_account,
    kubernetes_namespace.app_namespace
  ]
}
