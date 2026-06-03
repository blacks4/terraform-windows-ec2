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
    ansible_password     = optional(string)
    common_tags          = optional(map(string), {})
  })
  default   = {}
  sensitive = true

  validation {
    condition     = length(trimspace(coalesce(var.global_settings.ansible_password, ""))) > 0
    error_message = "global_settings.ansible_password is required and cannot be empty."
  }
}

variable "instance_count" {
  description = "Number of Windows EC2 instances to create."
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "Default EC2 instance type used only when compute_nodes is empty."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of: t3.micro or t3.small."
  }
}

variable "compute_nodes" {
  description = "Map of uniquely named compute nodes. Map keys become EC2 Name tags. When set, this overrides instance_count/name_prefix/instance_type defaults."
  type = map(object({
    instance_type       = string
    data_disk_1_size_gb = optional(number, 0)
    tags                = optional(map(string), {})
  }))
  default = {}

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


variable "name_prefix" {
  description = "Prefix used for instance Name tags only when compute_nodes is empty."
  type        = string
  default     = "windows-ansible"
}

