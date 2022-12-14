
resource "aws_vpc" "this" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
}

data "aws_region" "this" {}



module "subnet_group_private" {
  source = "../modules/subnet_group"


  name          = "Subnet Group"
  vpc_id        = aws_vpc.this.id
  vpc_ipv4_cidr = aws_vpc.this.cidr_block
  vpc_ipv6_cidr = aws_vpc.this.ipv6_cidr_block

  availability_zone = "${data.aws_region.this.name}a"

  subnet_config = {
    private0        = { ipv4 = { cidr = 20, index = 0 }, ipv6 = { cidr = 64, index = 0 } }
    private1        = { ipv4 = { cidr = 20, index = 1 }, ipv6 = { cidr = 64, index = 1 } }
    private2        = { ipv4 = { cidr = 20, index = 2 }, ipv6 = { cidr = 64, index = 2 } }
    private3        = { ipv4 = { cidr = 20, index = 3 }, ipv6 = { cidr = 64, index = 3 } }
    private4        = { ipv4 = { cidr = 20, index = 4 }, ipv6 = { cidr = 64, index = 4 } }
    private5        = { ipv4 = { cidr = 20, index = 5 }, ipv6 = { cidr = 64, index = 5 } }
    private_routing = { ipv4 = { cidr = 24, index = -1 }, ipv6 = { cidr = 64, index = -1 } }
  }

  routes = {
    internet_gateway = { type = "igw", id = aws_internet_gateway.this.id, cidr_v4 = "0.0.0.0/0", cidr_v6 = "::/0" }
    #egress_gateway   = { type = "egw", id = aws_egress_only_internet_gateway.this.id, cidr_v6 = "::/0" }
    #nat_gateway2     = { type = "nat", id = aws_nat_gateway.this.id, cidr_v4 = "0.0.0.0/0" }
    #nat_gateway1     = { type = "nat", id = "", cidr_v4 = "0.0.0.0/0", cidr_v6 = "64:ff9b::/96" }

  }

}

output "name" {
  value = aws_egress_only_internet_gateway.this.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_egress_only_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}
