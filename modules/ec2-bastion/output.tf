output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_id" {
  value = aws_instance.bastion.id
}

output "bastion_sg_id" {
  description = "The ID of the Bastion security group"
  value       = aws_security_group.bastion_sg.id
}

output "bastion_ssm_role_arn" {
  description = "ARN of the Bastion SSM IAM Role"
  value       = aws_iam_role.bastion_role.arn
}
