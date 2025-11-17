resource "time_sleep" "wait_for_cluster" {
  depends_on = [var.cluster_name]
  create_duration = "30s"
}

# Service Account
resource "kubernetes_service_account_v1" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller_role.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/part-of"    = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  depends_on = [time_sleep.wait_for_cluster]
}
