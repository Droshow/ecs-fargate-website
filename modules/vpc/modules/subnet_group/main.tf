terraform {
  experiments = [module_variable_optional_attrs]
}

locals {
  ipv4_cidr_match_regex = "^(?P<ip>\\d+.\\d+.\\d+.\\d+)\\/(?P<cidr>\\d+)$"
  ipv4_cidr_block_info  = regex(local.ipv4_cidr_match_regex, var.vpc_ipv4_cidr)
  ipv4_cidr_block_cidr  = tonumber(local.ipv4_cidr_block_info.cidr)
  ipv4_cidr_block_ip    = local.ipv4_cidr_block_info.ip
}

locals {
  # precalculate the number of subnets that would fit in for each possible subnet size
  ipv4_num_subnets = {
    for v in range(16, 30, 1) : # iterate from 16 to 30
    "${v}" => (local.ipv4_cidr_block_cidr > v ? 0 : pow(2, v - local.ipv4_cidr_block_cidr))
  }

  # convert the blocks from cidr classes (e.g. '/24') to a number of bits relative to 
  # vpc cidr, such that the function cidrsubnet() understands it.
  # E.g. for a /16 vpc with a /24 subnet, the result should be 8
  ipv4_subnet_size = {
    for k, v in var.subnet_config :
    k => v.ipv4.cidr - local.ipv4_cidr_block_cidr
  }

  ipv4_subnet_index = {
    for k, v in var.subnet_config :
    k => (
      v.ipv4.index >= 0 ?
      v.ipv4.index :
      local.ipv4_num_subnets[v.ipv4.cidr] + v.ipv4.index
    )
  }
}

locals {

  # TODO Is it even possible to get something different in AWS?
  ipv6_cidr_block_cidr = 56

  # precalculate the number of subnets that would fit in for each possible subnet size
  ipv6_num_subnets = {
    for v in range(56, 65, 1) : # iterate from 56 to 64
    "${v}" => (local.ipv6_cidr_block_cidr > v ? 0 : pow(2, v - local.ipv6_cidr_block_cidr))
  }

  # convert the blocks from cidr classes (e.g. '/24') to a number of bits relative to 
  # vpc cidr, such that the function cidrsubnet() understands it.
  # E.g. for a /16 vpc with a /24 subnet, the result should be 8
  ipv6_subnet_size = {
    for k, v in var.subnet_config :
    k => v.ipv6.cidr - local.ipv6_cidr_block_cidr
  }

  ipv6_subnet_index = {
    for k, v in var.subnet_config :
    k => (
      v.ipv6.index >= 0 ?
      v.ipv6.index :
      local.ipv6_num_subnets[v.ipv6.cidr] + v.ipv6.index
    )
  }
}

resource "aws_subnet" "this" {
  for_each = var.subnet_config
  vpc_id   = var.vpc_id

  cidr_block = cidrsubnet(
    var.vpc_ipv4_cidr,
    local.ipv4_subnet_size[each.key],
    local.ipv4_subnet_index[each.key]
  )

  ipv6_cidr_block = cidrsubnet(
    var.vpc_ipv6_cidr,
    local.ipv6_subnet_size[each.key],
    local.ipv6_subnet_index[each.key]
  )

  tags = {
    "Name" = "${var.name}-${each.key}"
  }
}

# -- RouteTable --------------------------------------------------------

resource "aws_route_table" "this" {
  vpc_id = var.vpc_id
  tags = {
    Name = var.name
  }
}
resource "aws_route_table_association" "this" {
  for_each       = aws_subnet.this
  route_table_id = aws_route_table.this.id
  subnet_id      = each.value.id
}

# -- IGW, EGWs, NATs --------------------------------------------------------

locals {
  igw4_routes = { for k, v in var.routes : k => v if v.type == "igw" && v.cidr_v4 != null }
  igw6_routes = { for k, v in var.routes : k => v if v.type == "igw" && v.cidr_v6 != null }
  egw_routes  = { for k, v in var.routes : k => v if v.type == "egw" }
  nat4_routes = { for k, v in var.routes : k => v if v.type == "nat" && v.cidr_v4 != null }
  nat6_routes = { for k, v in var.routes : k => v if v.type == "nat" && v.cidr_v6 != null }
}

resource "aws_route" "igw4" {
  for_each               = local.igw4_routes
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = each.value.cidr_v4
  gateway_id             = each.value.id
}


resource "aws_route" "igw6" {
  for_each                    = local.igw6_routes
  route_table_id              = aws_route_table.this.id
  destination_ipv6_cidr_block = each.value.cidr_v6
  gateway_id                  = each.value.id
}

resource "aws_route" "egw6" {
  for_each                    = local.egw_routes
  route_table_id              = aws_route_table.this.id
  destination_ipv6_cidr_block = each.value.cidr_v6
  gateway_id                  = each.value.id
}

resource "aws_route" "nat4" {
  for_each               = local.nat4_routes
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = each.value.cidr_v4
  gateway_id             = each.value.id
}

resource "aws_route" "nat6" {
  for_each                    = local.nat6_routes
  route_table_id              = aws_route_table.this.id
  destination_ipv6_cidr_block = each.value.cidr_v6
  gateway_id                  = each.value.id
}
