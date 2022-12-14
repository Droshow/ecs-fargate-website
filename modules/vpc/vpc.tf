# vpc.tf
#
# Module:    vpc_dualstack
# Author:    Benjamin Kulnik
# Project:   vpc_dualstack
# Date:      2022 August 


# -- Networking Config --------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block                       = var.cidr_block_ipv4
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.extra_tags_vpc
  )
}

resource "aws_subnet" "this" {
  for_each          = var.subnet_config
  vpc_id            = aws_vpc.this.id
  availability_zone = "${local.deployment_region}${each.value.availability_zone}"

  cidr_block = cidrsubnet(
    aws_vpc.this.cidr_block,
    local.ipv4_subnet_size[each.key],
    local.ipv4_subnet_index[each.key]
  )

  ipv6_cidr_block = cidrsubnet(
    aws_vpc.this.ipv6_cidr_block,
    local.ipv6_subnet_size[each.key],
    local.ipv6_subnet_index[each.key]
  )

  map_public_ip_on_launch                        = each.value.type == "public"
  assign_ipv6_address_on_creation                = true
  enable_dns64                                   = false # not needed in dual stack vpcs
  enable_resource_name_dns_a_record_on_launch    = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  private_dns_hostname_type_on_launch            = var.subnet_private_dns_hostname_type_on_launch



  tags = merge(
    { "Name" = "${var.name}-${each.key}" },
    var.tags,
    var.extra_tags_subnets
  )
}


resource "aws_subnet" "routing" {
  for_each          = var.routing_subnet_config
  vpc_id            = aws_vpc.this.id
  availability_zone = "${local.deployment_region}${each.value.availability_zone}"

  cidr_block = cidrsubnet(
    aws_vpc.this.cidr_block,
    local.ipv4_routing_subnet_size[each.key],
    local.ipv4_routing_subnet_index[each.key]
  )

  ipv6_cidr_block = cidrsubnet(
    aws_vpc.this.ipv6_cidr_block,
    local.ipv6_routing_subnet_size[each.key],
    local.ipv6_routing_subnet_index[each.key]
  )

  map_public_ip_on_launch                        = each.value.type == "public"
  assign_ipv6_address_on_creation                = true
  enable_dns64                                   = false
  enable_resource_name_dns_a_record_on_launch    = true
  enable_resource_name_dns_aaaa_record_on_launch = true
  private_dns_hostname_type_on_launch            = var.subnet_private_dns_hostname_type_on_launch

  tags = merge(
    { "Name" = "${var.name}-routing-${each.key}" },
    var.tags,
    var.extra_tags_routing_subnets
  )
}

# -- Route Tables --------------------------------------------------------

locals {
  sn_public  = { for key, sn in aws_subnet.this : key => sn if var.subnet_config[key].type == "public" }
  sn_private = { for key, sn in aws_subnet.this : key => sn if var.subnet_config[key].type == "private" }
  sn_egress  = { for key, sn in aws_subnet.this : key => sn if var.subnet_config[key].type == "egress_only" }


  # Subnet + AZ Pairs
  sn_public_azs = {
    for az in local.azs_distinct :
    az => [for key, sn in var.subnet_config : {
      subnet_key        = key
      availability_zone = az
      }
    if sn.availability_zone == az && sn.type == "public"]
  }
  # Helper: Unnest the Subnet/AZ pairs and create a unqiue key
  sn_public_azs_flat  = flatten([for key, az in local.sn_public_azs : az])
  sn_public_azs_flat2 = { for v in local.sn_public_azs_flat : "${v.subnet_key}-${v.availability_zone}" => v }



  sn_private_azs = {
    for az in local.azs_distinct :
    az => [for key, sn in var.subnet_config : {
      subnet_key        = key
      availability_zone = az
    } if sn.availability_zone == az && sn.type == "private"]
  }
  sn_private_azs_flat  = flatten([for key, az in local.sn_private_azs : az])
  sn_private_azs_flat2 = { for v in local.sn_private_azs_flat : "${v.subnet_key}-${v.availability_zone}" => v }



  sn_egress_azs = {
    for az in local.azs_distinct :
    az => [for key, sn in var.subnet_config : {
      subnet_key        = key
      availability_zone = az
    } if sn.availability_zone == az && sn.type == "egress_only"]
  }
  sn_egress_azs_flat  = flatten([for key, az in local.sn_egress_azs : az])
  sn_egress_azs_flat2 = { for v in local.sn_egress_azs_flat : "${v.subnet_key}-${v.availability_zone}" => v }


  sn_public_routing_azs = {
    for az in local.azs_distinct :
    az => [for key, sn in var.routing_subnet_config : {
      subnet_key        = key
      availability_zone = az
      }
    if sn.availability_zone == az && sn.type == "public"]
  }
  sn_public_routing_azs_flat  = flatten([for key, az in local.sn_public_routing_azs : az])
  sn_public_routing_azs_flat2 = { for v in local.sn_public_routing_azs_flat : "${v.subnet_key}-${v.availability_zone}" => v }

  sn_private_routing_azs = {
    for az in local.azs_distinct :
    az => [for key, sn in var.routing_subnet_config : {
      subnet_key        = key
      availability_zone = az
      }
    if sn.availability_zone == az && sn.type == "private"]
  }
  sn_private_routing_azs_flat  = flatten([for key, az in local.sn_private_routing_azs : az])
  sn_private_routing_azs_flat2 = { for v in local.sn_private_routing_azs_flat : "${v.subnet_key}-${v.availability_zone}" => v }


}

# Uncomment this to see how the intermediate values look like
# output "debug_azs" {
#   value = {
#     public       = local.sn_public_azs
#     public_flat  = local.sn_public_azs_flat
#     public_flat2 = local.sn_public_azs_flat2
#     private      = local.sn_private_azs
#     egress       = local.sn_egress_azs
#   }
# }



resource "aws_route_table" "public" {
  for_each = local.sn_public_azs
  vpc_id   = aws_vpc.this.id

  tags = merge(
    { Name = "${var.name}-public-${each.key}" },
    var.tags,
    var.extra_tags_routing_tables
  )
}

resource "aws_route_table" "private" {
  for_each = local.sn_private_azs
  vpc_id   = aws_vpc.this.id
  tags = merge(
    { Name = "${var.name}-private-${each.key}" },
    var.tags,
    var.extra_tags_routing_tables
  )
}

resource "aws_route_table" "egress" {
  for_each = local.sn_egress_azs
  vpc_id   = aws_vpc.this.id
  tags = merge(
    { Name = "${var.name}-egress-only-${each.key}" },
    var.tags,
    var.extra_tags_routing_tables
  )
}

resource "aws_route_table" "public_routing" {
  for_each = local.sn_public_routing_azs
  vpc_id   = aws_vpc.this.id
  tags = merge(
    { Name = "${var.name}-routing-private-${each.key}" },
    var.tags,
    var.extra_tags_routing_tables
  )

}

resource "aws_route_table" "private_routing" {
  for_each = local.sn_private_routing_azs
  vpc_id   = aws_vpc.this.id
  tags = merge(
    { Name = "${var.name}-routing-public-${each.key}" },
    var.tags,
    var.extra_tags_routing_tables
  )
}

resource "aws_route_table_association" "public" {
  for_each       = local.sn_public_azs_flat2
  subnet_id      = aws_subnet.this[each.value.subnet_key].id
  route_table_id = aws_route_table.public[each.value.availability_zone].id
}

resource "aws_route_table_association" "private" {
  for_each       = local.sn_private_azs_flat2
  subnet_id      = aws_subnet.this[each.value.subnet_key].id
  route_table_id = aws_route_table.private[each.value.availability_zone].id
}

resource "aws_route_table_association" "egress" {
  for_each       = local.sn_egress_azs_flat2
  subnet_id      = aws_subnet.this[each.value.subnet_key].id
  route_table_id = aws_route_table.egress[each.value.availability_zone].id
}

resource "aws_route_table_association" "public_routing" {
  for_each       = local.sn_public_routing_azs_flat2
  subnet_id      = aws_subnet.routing[each.value.subnet_key].id
  route_table_id = aws_route_table.public_routing[each.value.availability_zone].id
}

resource "aws_route_table_association" "private_routing" {
  for_each       = local.sn_private_routing_azs_flat2
  subnet_id      = aws_subnet.routing[each.value.subnet_key].id
  route_table_id = aws_route_table.private_routing[each.value.availability_zone].id
}

locals {
  route_table_ids_private = [for rt in aws_route_table.private : rt.id]
  route_table_ids_public  = [for rt in aws_route_table.public : rt.id]
  route_table_ids_egress  = [for rt in aws_route_table.egress : rt.id]
  route_table_ids_all     = toset(concat(local.route_table_ids_private, local.route_table_ids_public, local.route_table_ids_egress))
}


# -- DHCP --------------------------------------------------------

# TODO Yet experimental, integration with Route53 needs to be researched
resource "aws_vpc_dhcp_options" "this" {
  count               = var.dhcp_domain_name != null ? 1 : 0
  domain_name         = var.dhcp_domain_name
  domain_name_servers = ["AmazonProvidedDNS"]
  tags                = merge({ Name = var.name }, var.tags)
}

resource "aws_vpc_dhcp_options_association" "this" {
  count           = var.dhcp_domain_name != null ? 1 : 0
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}


