
# -- Routing --------------------------------------------------------


# -- IGW + EGW --------------------------------------------------------
# Internet Gateway is created in every case, because it doesnt cost anything
# anyway. The same is true for egress-only gateway. For public subnets and 
# egress only subnets, routes to the gateways are established.

resource "aws_egress_only_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    { Name = "${var.name}-egw" },
    var.tags
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    { Name = "${var.name}-igw" },
    var.tags
  )
}

resource "aws_route" "igw4" {
  for_each               = aws_route_table.public
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "igw4routing" {
  for_each               = aws_route_table.public_routing
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "igw6" {
  for_each                    = aws_route_table.public
  route_table_id              = each.value.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this.id
}

resource "aws_route" "igw6routing" {
  for_each                    = aws_route_table.public_routing
  route_table_id              = each.value.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this.id
}

resource "aws_route" "egw6" {
  for_each                    = aws_route_table.egress
  route_table_id              = each.value.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.this.id
}


# -- NAT Deployment --------------------------------------------------------
# NAT Deployment is more difficult than IGW/EGW. Because it is associated with costs there are different ways
# to actually deploy it.
# Options:
#   - None:        No NAT gateway is deployed, no routes are created.
#   - Single:      A single NAT Gateway is deployed in the FIRST public routing subnet. All routes from all AZs are linked to this NAT gateway.
#   - OnePerAz:    One NAT Gateway is deployed per AZ. If there is more than one public routing subnet per AZ it is deployed to the first one. 
#                  The route tables are configures in such a way that the NAT Gateway is used which is in the same AZ as the Route Table to 
#                  avoid unnecessary delays.
#   - EverySubnet: One NAT Gateway is deployed in EVERY public routing subnet. At the moment, I cannot think of a single use case of this, so
#                  it is not implemented for now.

locals {

  sn_routing_config_public        = [for sn in var.routing_subnet_config : sn if sn.type == "public"]
  sn_routing_config_private       = [for sn in var.routing_subnet_config : sn if sn.type == "private"]
  sn_routing_public_distinct_azs  = distinct([for sn in var.routing_subnet_config : sn.availability_zone if sn.type == "public"])
  sn_routing_private_distinct_azs = distinct([for sn in var.routing_subnet_config : sn.availability_zone if sn.type == "private"])


  # --- case for OnePerAz deployment
  # List of public routing subnets per AZ
  nat_az_subnets_one_per_az = {
    for az in local.sn_routing_public_distinct_azs : az => [
      for key, sn in var.routing_subnet_config : key if sn.type == "public"
    ]
  }

  # --- case for single NAT deployemnt
  nat_single_az = local.sn_routing_public_distinct_azs[0] # pick the first distinct az
  nat_az_subnets_single = {
    (local.nat_single_az) = [for key, sn in var.routing_subnet_config : key if sn.availability_zone == local.nat_single_az]
  }

  # Create a lookup table
  nat_az_subnets = {
    None     = {}
    Single   = local.nat_az_subnets_single
    OnePerAz = local.nat_az_subnets_one_per_az
  }

}

resource "aws_eip" "this" {
  for_each = local.nat_az_subnets[var.nat_deployment]
  vpc      = true
  tags = merge(
    { Name = "${var.name}-nat-gw-${each.key}" },
    var.tags
  )
}

resource "aws_nat_gateway" "this" {
  for_each      = local.nat_az_subnets[var.nat_deployment]
  subnet_id     = aws_subnet.routing[each.value[0]].id # pick the first subnet in case there is more than one routing subnet per az
  allocation_id = aws_eip.this[each.key].id
  tags = merge(
    { Name = "${var.name}-nat-gw-${each.key}" },
    var.tags,
    var.extra_tags_nat
  )
}

locals {

  nat_default = lookup(aws_nat_gateway.this, local.nat_single_az, null)

  nat_per_az = {
    for az in local.sn_routing_private_distinct_azs :
    az => lookup(aws_nat_gateway.this, az, local.nat_default)
  }
}

# output "debug_nat_routes_id" {
#   value = {
#     nat_default    = local.nat_default
#     nat_ids_per_az = local.nat_per_az
#   }
# }



resource "aws_route" "egress2nat" {
  for_each = {
    for k, v in aws_route_table.egress :
    k => v
    if local.nat_per_az[k] != null
  }
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.nat_per_az[each.key].id
}



