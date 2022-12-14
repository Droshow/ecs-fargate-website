# -- General --------------------------------------------------------

data "aws_region" "current" {}

data "aws_availability_zones" "azs" {}

locals {
  deployment_region = data.aws_region.current.name
}


# -- IPv4 Infos --------------------------------------------------------

locals {
  ipv4_cidr_match_regex = "^(?P<ip>\\d+.\\d+.\\d+.\\d+)\\/(?P<cidr>\\d+)$"  # matches strings like '10.0.0.0/24'
  ipv4_cidr_block_info  = regex(local.ipv4_cidr_match_regex, var.cidr_block_ipv4)
  ipv4_cidr_block_cidr  = tonumber(local.ipv4_cidr_block_info.cidr)
  ipv4_cidr_block_ip    = local.ipv4_cidr_block_info.ip
  
  # Calculate the number of subnets that are possible for each cidr block
  ipv4_num_subnets = {
    for v in range(16, 30, 1) : # iterate from 16 to 30
    "${v}" => (local.ipv4_cidr_block_cidr > v ? 0 : pow(2, v - local.ipv4_cidr_block_cidr))
  }

  # Calculate the actual size of the subnets based on their CIDR and the VPC CIDR. This is
  # used for the cidrsubnet() function.
  ipv4_subnet_size = {
    for k, v in var.subnet_config :
    k => v.ipv4.cidr - local.ipv4_cidr_block_cidr
  }

  # do the same for the routing subnets
  ipv4_routing_subnet_size = {
    for k, v in var.routing_subnet_config :
    k => v.ipv4.cidr - local.ipv4_cidr_block_cidr
  }

  # Convert negative index values into positive ones. A negative index value is counted from
  # the end (the last possible subnet index).
  ipv4_subnet_index = {
    for k, v in var.subnet_config :
    k => (
      v.ipv4.index >= 0 ?
      v.ipv4.index :
      local.ipv4_num_subnets[v.ipv4.cidr] + v.ipv4.index
    )
  }

  # do the same for the routing subnets
  ipv4_routing_subnet_index = {
    for k, v in var.routing_subnet_config :
    k => (
      v.ipv4.index >= 0 ?
      v.ipv4.index :
      local.ipv4_num_subnets[v.ipv4.cidr] + v.ipv4.index
    )
  }
}

# output "debug_ipv4_parsing" {
#   value = {
#     cidr           = local.ipv4_cidr_block_cidr
#     ip             = local.ipv4_cidr_block_ip
#   }
# }

# -- IPv6 --------------------------------------------------------


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
  #
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

  ipv6_routing_subnet_size = {
    for k, v in var.routing_subnet_config :
    k => v.ipv6.cidr - local.ipv6_cidr_block_cidr
  }

  ipv6_routing_subnet_index = {
    for k, v in var.routing_subnet_config :
    k => (
      v.ipv6.index >= 0 ?
      v.ipv6.index :
      local.ipv6_num_subnets[v.ipv6.cidr] + v.ipv6.index
    )
  }
}



# -- AZs --------------------------------------------------------

locals {
  sn_types = toset(["private", "public", "egress_only"])


  # Find the distinct azs of the regular subnets and the routing subnets
  azs_distinct = toset(
    distinct(
      concat(
        [for key, sn in var.subnet_config : sn.availability_zone],
        [for key, sn in var.routing_subnet_config : sn.availability_zone]
      )
    )
  )

  az_sn_combined_flat = flatten([
    for az in local.azs_distinct : [
      for sn_type in local.sn_types : {
        "az" = az
        "sn" = sn_type
      }
    ]
  ])
  az_sn = { for i in local.az_sn_combined_flat : "${i.az}-${i.sn}" => i }
}


