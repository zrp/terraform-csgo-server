locals {
  # Get current environment
  env = var.env
  app = var.app

  # Networking
  subnet_id = var.subnet_id
  vpc_id    = data.aws_vpc.this.id

  # Computing
  instance_type = var.instance_type

  # Server options
  rcon_password     = random_password.rcon_password.result
  gslt              = var.gslt
  max_players       = var.max_players
  slack_webhook_url = var.slack_webhook_url
  sv_password       = var.sv_password
  sv_contact        = var.sv_contact
  sv_tags           = var.sv_tags
  sv_region         = var.sv_region
  tickrate          = var.tickrate
}

/** Data Sources */
# Retrieve the subnet by id
data "aws_subnet" "public" {
  id = local.subnet_id
}

# Retrieve the provided subnet vpc and default security group
data "aws_vpc" "this" {
  id = data.aws_subnet.public.vpc_id
}

# Find the latest release of Ubuntu 20
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu*20.04*amd64-server*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Published by Canonical
  owners = ["099720109477"]
}

data "template_file" "lgsm" {
  template = file("${path.module}/templates/lgsm.tpl")
  vars = {
    default_map       = "de_dust2"
    max_players       = "32"
    slack_alert       = local.slack_webhook_url != "" ? "on" : "off"
    tickrate          = local.tickrate
    slack_webhook_url = local.slack_webhook_url
    gslt              = local.gslt
  }
}

data "template_file" "server" {
  template = file("${path.module}/templates/server.tpl")
  vars = {
    hostname      = "ZRP"
    rcon_password = local.rcon_password
    sv_password   = local.sv_password
    sv_contact    = local.sv_contact
    sv_tags       = local.sv_tags
    sv_region     = local.sv_region
  }
}

data "template_file" "xstartup" {
  template = file("${path.module}/templates/xstartup.tpl")
}

data "template_file" "autoexec" {
  template = file("${path.module}/templates/autoexec.tpl")
}

# /** Modules */
module "security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = ">= 4.17"
  name        = join("-", [local.env, local.app, "security"])
  description = "Security group for CSGO Server"
  vpc_id      = local.vpc_id
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 27000
      to_port     = 27020
      protocol    = "tcp"
      description = "User-Service Ports TCP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 27000
      to_port     = 27020
      protocol    = "udp"
      description = "User-Service Ports UDP"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 5901
      to_port     = 5901
      protocol    = "tcp"
      description = "VNC Service Ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules            = ["all-all"]
  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks = ["::/0"]
}

# /** Resources */
resource "aws_default_security_group" "this" {
  vpc_id = data.aws_vpc.this.id
}

resource "random_password" "rcon_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = join("-", [local.env, local.app, "ssh"])
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_file" "id_rsa" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.root}/id_rsa.pem"
  file_permission = 400
}

resource "local_file" "id_rsa_pub" {
  content         = tls_private_key.ssh.public_key_pem
  filename        = "${path.root}/id_rsa.pub"
  file_permission = 755
}

resource "aws_ssm_parameter" "pk" {
  name  = "/${local.app}/${local.env}/SSHPrivateKey"
  type  = "SecureString"
  value = tls_private_key.ssh.private_key_pem
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = local.instance_type
  key_name                    = aws_key_pair.ssh.key_name
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.public.id

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  vpc_security_group_ids = [
    aws_default_security_group.this.id,
    module.security_group.security_group_id
  ]

  tags = {
    "Name" = join("-", [local.env, local.app, "server"])
  }

  connection {
    host        = aws_instance.server.public_ip
    type        = "ssh"
    user        = "csgoserver"
    private_key = tls_private_key.ssh.private_key_pem
  }

  # Create user for server
  provisioner "remote-exec" {
    connection {
      host        = aws_instance.server.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_pem
    }

    script = "${path.module}/scripts/create-user.sh"
  }

  # Setup
  provisioner "remote-exec" {
    inline = [
      "mkdir /home/csgoserver/.vnc",
      "chmod 755 /home/csgoserver/.vnc"
    ]
  }
  provisioner "file" {
    content     = data.template_file.xstartup.rendered
    destination = "/home/csgoserver/.vnc/xstartup"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod u+x /home/csgoserver/.vnc/xstartup",
      "chmod 777 /home/csgoserver/.vnc/xstartup"
    ]
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/setup.sh"
  }

  # # Download and config CS:GO server
  provisioner "remote-exec" {
    inline = [
      "./csgoserver auto-install",
    ]
  }

  # # Upload server config
  provisioner "file" {
    content     = data.template_file.lgsm.rendered
    destination = "/home/csgoserver/lgsm/config-lgsm/csgoserver/common.cfg"
  }

  provisioner "file" {
    content     = data.template_file.server.rendered
    destination = "/home/csgoserver/serverfiles/csgo/cfg/csgoserver.cfg"
  }

  provisioner "file" {
    content     = data.template_file.autoexec.rendered
    destination = "/home/csgoserver/serverfiles/csgo/cfg/autoexec.cfg"
  }

  # # Start
  provisioner "remote-exec" {
    inline = [
      "chmod 775 /home/csgoserver/lgsm/config-lgsm/csgoserver/common.cfg",
      "chmod 775 /home/csgoserver/serverfiles/csgo/cfg/csgoserver.cfg",
      "chmod 775 /home/csgoserver/serverfiles/csgo/cfg/autoexec.cfg",
      "./csgoserver start",
    ]
  }
}

# Associate an EIP
resource "aws_eip" "this" {
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.this.id
}
