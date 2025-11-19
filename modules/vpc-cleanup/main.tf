resource "null_resource" "vpc_sg_cleanup" {
  triggers = {
    region    = var.region
    vpc_cidr  = var.vpc_cidr
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "=== VPC Security Group Cleanup Started ==="
      
      vpc_id=$(aws ec2 describe-vpcs --region ${self.triggers.region} \
        --filters "Name=cidr-block-association.cidr-block,Values=${self.triggers.vpc_cidr}" \
        --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")
      
      if [ "$vpc_id" = "None" ] || [ -z "$vpc_id" ]; then
        echo "VPC not found, cleanup complete"
        exit 0
      fi
      
      echo "Cleaning security groups in VPC: $vpc_id"
      
      for attempt in {1..5}; do
        sgs=$(aws ec2 describe-security-groups --region ${self.triggers.region} \
          --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=k8s-*" \
          --query "SecurityGroups[].GroupId" --output text 2>/dev/null || true)
        
        if [ -z "$sgs" ]; then
          echo "No k8s security groups found"
          break
        fi
        
        for sg in $sgs; do
          echo "Deleting security group: $sg"
          
          # Clear all rules
          aws ec2 describe-security-groups --group-ids $sg --region ${self.triggers.region} \
            --query "SecurityGroups[0].IpPermissions[]" --output json 2>/dev/null | \
            aws ec2 revoke-security-group-ingress --group-id $sg --region ${self.triggers.region} \
            --ip-permissions file:///dev/stdin 2>/dev/null || true
          
          aws ec2 describe-security-groups --group-ids $sg --region ${self.triggers.region} \
            --query "SecurityGroups[0].IpPermissionsEgress[]" --output json 2>/dev/null | \
            aws ec2 revoke-security-group-egress --group-id $sg --region ${self.triggers.region} \
            --ip-permissions file:///dev/stdin 2>/dev/null || true
          
          aws ec2 delete-security-group --group-id $sg --region ${self.triggers.region} 2>/dev/null || true
        done
        
        sleep 3
      done
      
      echo "=== VPC Security Group Cleanup Completed ==="
    EOT
  }
}
