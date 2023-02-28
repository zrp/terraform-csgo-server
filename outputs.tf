output "public_ssh_key" {
  description = "SSH Public Key"
  value       = tls_private_key.ssh.public_key_openssh
}

output "private_ssh_key_path" {
  description = "The SSM paramter path holding the SSH private key (in PEM format)"
  value       = aws_ssm_parameter.pk.name
}

output "instance_public_ip" {
  description = "Instance Public IP"
  value       = aws_eip.this.public_ip
}

output "instance_arn" {
  value = aws_instance.server.arn
}

output "rcon_password" {
  sensitive   = true
  description = "Password String"
  value       = local.rcon_password
}
