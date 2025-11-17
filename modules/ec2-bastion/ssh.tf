# Generate SSH key pair
resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = "${path.root}/keys/${var.instance_name}.pem"
  file_permission = "0400"
}

# AWS Key Pair
resource "aws_key_pair" "bastion_key" {
  key_name   = "${var.project_name}-${var.env_name}-bastion-key"
  public_key = tls_private_key.bastion_key.public_key_openssh
}
