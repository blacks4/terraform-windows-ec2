output "instance_ids" {
  description = "IDs of created Windows EC2 instances keyed by node name."
  value = {
    for node_name, instance in aws_instance.windows_vm :
    node_name => instance.id
  }
}

output "private_ips" {
  description = "Private IP addresses of created Windows EC2 instances keyed by node name."
  value = {
    for node_name, instance in aws_instance.windows_vm :
    node_name => instance.private_ip
  }
}

output "public_ips" {
  description = "Public IP addresses of created Windows EC2 instances keyed by node name (if assigned)."
  value = {
    for node_name, instance in aws_instance.windows_vm :
    node_name => instance.public_ip
  }
}

output "data_disk_1_ids" {
  description = "EBS volume IDs for optional data_disk_1 attachments keyed by node name."
  value = {
    for node_name, disk in aws_ebs_volume.data_disk_1 :
    node_name => disk.id
  }
}

output "security_group_id" {
  description = "Security group ID attached to the Windows instances."
  value       = aws_security_group.windows_vm_sg.id
}
