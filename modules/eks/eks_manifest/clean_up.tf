resource "null_resource" "production_cleanup" {
  count = var.create_manifests ? 1 : 0
  
  triggers = {
    region           = var.region
    vpc_id           = var.vpc_id
    cluster_name     = var.eks_cluster_name
    project_name     = var.project_name
    env_name         = var.env_name
  }
  
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "=== Starting Production-Ready Cleanup ==="
      
      # Update kubeconfig
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} || true
      
      # Check if any targetgroupbindings exist in monitoring namespace
if kubectl get targetgroupbinding -n monitoring --no-headers 2>/dev/null | grep -q .; then
    echo "TargetGroupBindings found in monitoring namespace. Removing finalizers and deleting..."

    # Remove finalizers
    kubectl get targetgroupbinding -n monitoring -o name \
    | xargs -I {} kubectl patch {} -n monitoring --type=merge -p '{"metadata":{"finalizers":null}}'

    # Delete targetgroupbindings
    kubectl get targetgroupbinding -n monitoring -o name \
    | xargs -I {} kubectl delete {} -n monitoring --force --grace-period=0

else
    echo "No TargetGroupBindings found in monitoring namespace. Nothing to delete."
fi

      
      # Force delete ingresses with finalizer removal - handle not found gracefully
      echo "--- Force deleting ingresses ---"
      
      # Check if grafana ingress exists before attempting deletion
      if kubectl get ingress ${self.triggers.project_name}-${self.triggers.env_name}-grafana -n monitoring >/dev/null 2>&1; then
        echo "Deleting grafana ingress..."
        kubectl patch ingress ${self.triggers.project_name}-${self.triggers.env_name}-grafana -n monitoring -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        kubectl delete ingress ${self.triggers.project_name}-${self.triggers.env_name}-grafana -n monitoring --force --grace-period=0 || true
      else
        echo "grafana ingress not found, skipping deletion"
      fi
      
      # Check if argocd ingress exists before attempting deletion
      if kubectl get ingress ${self.triggers.project_name}-${self.triggers.env_name}-argocd -n argocd >/dev/null 2>&1; then
        echo "Deleting argocd ingress..."
        kubectl patch ingress ${self.triggers.project_name}-${self.triggers.env_name}-argocd -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        kubectl delete ingress ${self.triggers.project_name}-${self.triggers.env_name}-argocd -n argocd --force --grace-period=0 || true
      else
        echo "argocd ingress not found, skipping deletion"
      fi
      
      echo "--- Waiting for AWS Load Balancer Controller cleanup ---"
      sleep 120
      
      # Force cleanup ALBs created by ingresses
      echo "--- Cleaning up AWS Load Balancers ---"
      for lb_arn in $(aws elbv2 describe-load-balancers --region ${self.triggers.region} \
        --query "LoadBalancers[?VpcId=='${self.triggers.vpc_id}' && (contains(LoadBalancerName, 'k8s-') || contains(LoadBalancerName, '${self.triggers.project_name}-${self.triggers.env_name}'))].LoadBalancerArn" \
        --output text 2>/dev/null || true); do
        [ ! -z "$lb_arn" ] && aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region ${self.triggers.region} || true
      done
      
      sleep 60
      
      # Force cleanup target groups
      echo "--- Cleaning up Target Groups ---"
      for tg_arn in $(aws elbv2 describe-target-groups --region ${self.triggers.region} \
        --query "TargetGroups[?VpcId=='${self.triggers.vpc_id}' && contains(TargetGroupName, 'k8s-')].TargetGroupArn" \
        --output text 2>/dev/null || true); do
        [ ! -z "$tg_arn" ] && aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region ${self.triggers.region} || true
      done
      
      sleep 30
      
      # Cleanup security groups with proper dependency handling
      echo "--- Cleaning up Security Groups ---"
      for i in {1..3}; do
        sgs=$(aws ec2 describe-security-groups --region ${self.triggers.region} \
          --filters "Name=vpc-id,Values=${self.triggers.vpc_id}" "Name=group-name,Values=k8s-*" \
          --query "SecurityGroups[].GroupId" --output text 2>/dev/null || true)
        
        [ -z "$sgs" ] && break
        
        for sg_id in $sgs; do
          # Remove all ingress rules
          aws ec2 describe-security-groups --group-ids $sg_id --region ${self.triggers.region} \
            --query "SecurityGroups[0].IpPermissions" --output json 2>/dev/null | \
            jq -c '.[]?' 2>/dev/null | while read rule; do
              [ ! -z "$rule" ] && echo "$rule" | aws ec2 revoke-security-group-ingress \
                --group-id $sg_id --ip-permissions file:///dev/stdin --region ${self.triggers.region} 2>/dev/null || true
            done
          
          # Remove all egress rules except default
          aws ec2 describe-security-groups --group-ids $sg_id --region ${self.triggers.region} \
            --query "SecurityGroups[0].IpPermissionsEgress[?!(IpProtocol=='-1' && IpRanges[0].CidrIp=='0.0.0.0/0')]" \
            --output json 2>/dev/null | \
            jq -c '.[]?' 2>/dev/null | while read rule; do
              [ ! -z "$rule" ] && echo "$rule" | aws ec2 revoke-security-group-egress \
                --group-id $sg_id --ip-permissions file:///dev/stdin --region ${self.triggers.region} 2>/dev/null || true
            done
          
          aws ec2 delete-security-group --group-id $sg_id --region ${self.triggers.region} 2>/dev/null || true
        done
        
        sleep 20
      done
      
      echo "=== Production Cleanup Completed ==="
    EOT
  }
}