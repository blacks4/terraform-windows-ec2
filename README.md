# AWS Windows EC2 (Terraform)

This Terraform configuration deploys one or more Windows Server 2022 EC2 instances, creates and attaches a dedicated security group, and bootstraps WinRM plus a local admin user for Ansible access.

## What This Creates

- An AWS provider configuration (region from variable)
- A data lookup for the latest Amazon Windows Server 2022 AMI
- One security group with:
  - Full TCP/UDP/ICMP inbound from `global_settings.allowed_ingress_cidr`
  - Full inbound from `global_settings.local_network_cidr`
  - Full outbound to `local_network_cidr`
  - Full outbound to `0.0.0.0/0`
- One `aws_instance` per key in `compute_nodes` (preferred)
- Optional per-node EBS data disk (`data_disk_1`) when `data_disk_1_size_gb > 0`
- User data bootstrap that:
  - Enables WinRM over HTTP (5985)
  - Enables Basic auth + unencrypted transport
  - Opens Windows Firewall port 5985
  - Creates/ensures a local admin account for Ansible

## Important Security Notes

- This setup is intentionally permissive for trusted/lab use.
- WinRM is configured with Basic auth and unencrypted transport.
- Inbound rules allow broad access from the configured CIDRs.

For production, restrict inbound ports/CIDRs, prefer WinRM over HTTPS (5986), and use stronger identity and secret handling patterns.

## Prerequisites

- Terraform `>= 1.5.0`
- AWS credentials configured in your environment/profile
- Existing AWS networking resources:
  - VPC
  - Subnet
  - EC2 key pair

## Files

- `main.tf`: provider, AMI lookup, security group, EC2 instances
- `variables.tf`: input variables and defaults
- `outputs.tf`: instance and security group outputs
- `userdata.ps1.tftpl`: Windows bootstrap script
- `terraform.tfvars.example`: sample variable values

## Inputs

Required:

- `ansible_password` (sensitive)
- `compute_nodes` (map of unique node definitions)

Common optional inputs:

- `global_settings` (object for shared settings)

`global_settings` schema:

```hcl
global_settings = {
  aws_region           = "us-east-1"
  vpc_id               = "vpc-12345678"
  subnet_id            = "subnet-12345678"
  key_pair_name        = "2026_key"
  allowed_ingress_cidr = "1.2.3.4/32"
  local_network_cidr   = "172.31.16.0/24"
  security_group_name  = "windows-vm-allow-all-from-trusted-ip"
  ansible_username     = "ansible"
  common_tags          = { environment = "dev" }
}
```

```hcl
ansible_password = "REPLACE_WITH_STRONG_PASSWORD"
```

`compute_nodes` schema:

```hcl
compute_nodes = {
  "win-app-01" = {
    instance_type       = "t3.small" # allowed: t3.micro, t3.small
    data_disk_1_size_gb = 0            # optional, defaults to 0
    tags = {
      role  = "app"
      notes = "Primary node"
    }
  }
}
```

`compute_nodes` is limited to 10 nodes total.

See `variables.tf` for full defaults and descriptions.

## Usage

1. Initialize Terraform:

```bash
terraform init
```

2. Create a variable file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` and set at least:

```hcl
ansible_password = "REPLACE_WITH_STRONG_PASSWORD"
```

4. Review the plan:

```bash
terraform plan
```

5. Apply:

```bash
terraform apply
```

6. View outputs:

```bash
terraform output
```

## Outputs

- `instance_ids`
- `private_ips`
- `public_ips`
- `data_disk_1_ids`
- `security_group_id`

## Destroy

```bash
terraform destroy
```

## Notes for Ansible Connectivity

- WinRM HTTP endpoint: `5985`
- The bootstrap script ensures the configured `ansible_username` is in local `Administrators`.
- Ensure your controlling host can route to the target IPs and is allowed by security group rules.
