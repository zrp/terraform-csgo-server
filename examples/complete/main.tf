provider "aws" {
  region = local.region
}

locals {
  region = "sa-east-1"
}

variable "gslt" {}

## Modules
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "csgo-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["${local.region}a"]
  public_subnets = ["10.0.0.0/24"]

  enable_ipv6        = false
  enable_nat_gateway = false
  single_nat_gateway = false
}

## Create CS: GO server
module "csgo" {
  source = "../../"

  depends_on = [
    module.vpc
  ]

  # Get the first public subnet
  subnet_id = [for s in module.vpc.public_subnets : s][0]

  app = "csgo-ds"
  env = "example"

  slack_webhook_url = ""
  gslt              = var.gslt

  instance_type = "t3.large"

  tickrate    = 64
  sv_password = "zrp@1234"
  sv_contact  = "noreply@zrp.com.br"
  sv_region   = 2
  sv_tags     = "64-tick"
}

# Add some backup
module "backup" {
  source = "cloudposse/backup/aws"

  namespace = "csgo-ds"
  stage     = "example"
  name      = "backup"
  delimiter = "-"

  backup_resources = [module.csgo.instance_arn]
  rules = [
    {
      name              = "csgo-server-daily-backup"
      schedule          = "cron(0 12 * * ? *)"
      start_window      = 60
      completion_window = 120
      lifecycle = {
        cold_storage_after = 90
        delete_after       = 180
      }
    }
  ]
}

output "public_ssh_key" {
  value = module.csgo.public_ssh_key
}

output "private_ssh_key_path" {
  value = module.csgo.private_ssh_key_path
}

output "public_ip" {
  value = module.csgo.instance_public_ip
}

output "rcon_password" {
  value     = module.csgo.rcon_password
  sensitive = true
}
