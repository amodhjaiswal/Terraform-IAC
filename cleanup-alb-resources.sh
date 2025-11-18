#!/bin/bash

# Manual cleanup script for ALB resources
# Usage: ./cleanup-alb-resources.sh <region> <vpc-id> <cluster-name>

set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <region> <vpc-id> <cluster-name>"
    echo "Example: $0 us-west-2 vpc-12345678 my-eks-cluster"
    exit 1
fi

REGION=$1
VPC_ID=$2
CLUSTER_NAME=$3

echo "=== Manual ALB Cleanup ==="
echo "Region: $REGION"
echo "VPC ID: $VPC_ID"
echo "Cluster: $CLUSTER_NAME"
echo

# Clean up ALBs
echo "--- Cleaning ALBs ---"
aws elbv2 describe-load-balancers --region $REGION --output text \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" 2>/dev/null | \
  while read lb_arn; do
    if [ ! -z "$lb_arn" ] && [ "$lb_arn" != "None" ]; then
      lb_name=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --region $REGION --output text --query 'LoadBalancers[0].LoadBalancerName' 2>/dev/null || echo "")
      
      if [[ "$lb_name" == k8s-* ]]; then
        echo "Deleting ALB: $lb_arn ($lb_name)"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $REGION || true
      fi
    fi
  done

echo "Waiting 60 seconds for ALB deletion..."
sleep 60

# Clean up target groups
echo "--- Cleaning target groups ---"
aws elbv2 describe-target-groups --region $REGION --output text \
  --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" 2>/dev/null | \
  while read tg_arn; do
    if [ ! -z "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
      tg_name=$(aws elbv2 describe-target-groups --target-group-arns "$tg_arn" --region $REGION --output text --query 'TargetGroups[0].TargetGroupName' 2>/dev/null || echo "")
      
      if [[ "$tg_name" == k8s-* ]]; then
        echo "Deleting Target Group: $tg_arn ($tg_name)"
        aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region $REGION || true
      fi
    fi
  done

echo "Waiting 30 seconds for target group deletion..."
sleep 30

# Clean up security groups
echo "--- Cleaning ALB security groups ---"
aws ec2 describe-security-groups --region $REGION --output text \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[?starts_with(GroupName, 'k8s-')].GroupId" 2>/dev/null | \
  while read sg_id; do
    if [ ! -z "$sg_id" ] && [ "$sg_id" != "None" ]; then
      echo "Deleting Security Group: $sg_id"
      aws ec2 delete-security-group --group-id "$sg_id" --region $REGION 2>/dev/null || {
        echo "Removing rules from security group $sg_id"
        aws ec2 describe-security-groups --group-ids "$sg_id" --region $REGION \
          --query "SecurityGroups[0].IpPermissions[*]" --output json 2>/dev/null | \
          jq -c '.[]?' 2>/dev/null | while read rule; do
            if [ ! -z "$rule" ]; then
              aws ec2 revoke-security-group-ingress --group-id "$sg_id" --ip-permissions "$rule" --region $REGION || true
            fi
          done
        aws ec2 delete-security-group --group-id "$sg_id" --region $REGION || true
      }
    fi
  done

echo "=== Manual Cleanup Completed ==="
