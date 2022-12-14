# -- Example --------------------------------------------------------


module "vpc" {
  #source = "github.com/auvaria-internal/terraform-vpc-dualstack"
  source = "../../." # for local debugging

  name = "AwesomeApplication"

  cidr_block_ipv4 = "10.0.0.0/18"
  nat_deployment  = "OnePerAz"

  aws_service_gateway_endpoints         = ["s3", "dynamodb"]
  aws_service_interface_endpoints       = ["lakeformation"]
  aws_service_interface_deployment_type = "OnePerAz"

  subnet_config = {
    #  /-------- Dictionary key names to achieve deterministic behaviour when deploying resources.
    #  |
    #  |                        /----- The cidr tells how large the network should be (a '/24' network)
    #  |                        |
    #  |                        |           /--- The index determines the first ip. E.g. index = 2 on a /24 network is X.X.2.0/24
    #  |                        |           |
    #  V                        v           v
    private0 = { ipv4 = { cidr = 24, index = 0 }, ipv6 = { cidr = 64, index = 0 }, type = "private", availability_zone = "a" },
    private1 = { ipv4 = { cidr = 24, index = 1 }, ipv6 = { cidr = 64, index = 1 }, type = "private", availability_zone = "b" },
    private2 = { ipv4 = { cidr = 24, index = 2 }, ipv6 = { cidr = 64, index = 2 }, type = "private", availability_zone = "c" },
    public0  = { ipv4 = { cidr = 24, index = 11 }, ipv6 = { cidr = 64, index = 11 }, type = "public", availability_zone = "a" },
    public1  = { ipv4 = { cidr = 24, index = 12 }, ipv6 = { cidr = 64, index = 12 }, type = "public", availability_zone = "b" },
    public2  = { ipv4 = { cidr = 24, index = 13 }, ipv6 = { cidr = 64, index = 13 }, type = "public", availability_zone = "c" },
    egress0  = { ipv4 = { cidr = 24, index = 21 }, ipv6 = { cidr = 64, index = 21 }, type = "egress_only", availability_zone = "a" },
    egress1  = { ipv4 = { cidr = 24, index = 22 }, ipv6 = { cidr = 64, index = 22 }, type = "egress_only", availability_zone = "b" },
    egress2  = { ipv4 = { cidr = 24, index = 23 }, ipv6 = { cidr = 64, index = 23 }, type = "egress_only", availability_zone = "c" },
  }

  routing_subnet_config = {
    private0 = { ipv4 = { cidr = 24, index = -1 }, ipv6 = { cidr = 64, index = -1 }, type = "private", availability_zone = "a" },
    private1 = { ipv4 = { cidr = 24, index = -2 }, ipv6 = { cidr = 64, index = -2 }, type = "private", availability_zone = "b" },
    private2 = { ipv4 = { cidr = 24, index = -3 }, ipv6 = { cidr = 64, index = -3 }, type = "private", availability_zone = "c" },
    public0  = { ipv4 = { cidr = 24, index = -4 }, ipv6 = { cidr = 64, index = -4 }, type = "public", availability_zone = "a" },
    public1  = { ipv4 = { cidr = 24, index = -5 }, ipv6 = { cidr = 64, index = -5 }, type = "public", availability_zone = "b" },
    public2  = { ipv4 = { cidr = 24, index = -6 }, ipv6 = { cidr = 64, index = -6 }, type = "public", availability_zone = "c" },
  }



  flow_log_enabled = true
  flow_log_config = {
    log_group_name    = "ModernData"
    retention_in_days = 3
    traffic_type      = "ALL"
  }

  tags = {
    Stage = "development"
  }

  extra_tags_vpc = {
    ModernDataResourceGroup = "vpc"
  }

  extra_tags_subnets = {
    ModernDataResourceGroup = "subnet"
  }

  extra_tags_nat = {
    ModernDataResourceGroup = "nat"
  }

  extra_tags_routing_tables = {
    ModernDataResourceGroup = "rt"
  }

}

output "vpc_output" {
  value = module.vpc
}


module "bastion" {
  for_each              = toset(["egress0", "public0", "private0"])
  name                  = "bastion-host-${each.value}"
  source                = "github.com/auvaria-internal/terraform-bastion-host"
  subnet_id             = module.vpc.subnet_ids[each.value]
  key_should_be_created = true
  key_name              = "bk_pubkey"
  key_path              = "/Users/benjaminkulnik/.ssh/id_ed25519.pub"

  security_group_rules_ipv4 = {
    internet      = { from_port = 0, to_port = 0, protocol = "all", type = "egress", cidr_blocks = ["0.0.0.0/0"] }
    ssh_from_home = { from_port = 22, to_port = 22, protocol = "tcp", type = "ingress", cidr_blocks = ["62.178.150.25/32"] }
  }

  security_group_rules_ipv6 = {
    internet      = { from_port = 0, to_port = 0, protocol = "all", type = "egress", cidr_blocks = ["::/0"] }
    ssh_from_home = { from_port = 22, to_port = 22, protocol = "tcp", type = "ingress", cidr_blocks = ["2001:470:20a2::/48"] }
  }
}
