variable "global_settings" {
  description = "Global settings shared by all compute nodes."
  type = object({
    aws_region           = optional(string, "us-east-1")
    vpc_id               = optional(string, "vpc-0334ac8c5d7f1de47")
    subnet_id            = optional(string, "subnet-0fb42335a45532781")
    key_pair_name        = optional(string, "stractenberg-key-2022")
    allowed_ingress_cidr = optional(string, "108.5.84.156/32")
    local_network_cidr   = optional(string, "172.31.16.0/24")
    security_group_name  = optional(string, "windows-vm-allow-all-from-trusted-ip")
    ansible_username     = optional(string, "ansible")
    common_tags          = optional(map(string), {})
  })
  default = {}
}

variable "ansible_password" {
  description = "Password for the local Windows Ansible account used on all VMs."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.ansible_password)) > 0
    error_message = "ansible_password is required and cannot be empty."
  }
}

variable "compute_nodes" {
  description = "Map of uniquely named compute nodes. Map keys become EC2 Name tags."
  type = map(object({
    instance_type       = string
    data_disk_1_size_gb = optional(number, 0)
    tags                = optional(map(string), {})
  }))

  validation {
    condition     = length(var.compute_nodes) > 0
    error_message = "compute_nodes is required and must contain at least one node."
  }

  validation {
    condition     = length(var.compute_nodes) <= 10
    error_message = "compute_nodes cannot contain more than 10 nodes."
  }

  validation {
    condition = alltrue([
      for node in values(var.compute_nodes) : contains(["t3.micro", "t3.small"], node.instance_type)
    ])
    error_message = "Each compute_nodes[*].instance_type must be one of: t3.micro or t3.small."
  }

  validation {
    condition = alltrue([
      for node in values(var.compute_nodes) : node.data_disk_1_size_gb >= 0
    ])
    error_message = "Each compute_nodes[*].data_disk_1_size_gb must be greater than or equal to 0."
  }
}

