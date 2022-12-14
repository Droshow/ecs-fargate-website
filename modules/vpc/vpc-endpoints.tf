
# -- Gateway Endpoints --------------------------------------------------------


data "aws_vpc_endpoint_service" "aws_gateway" {
  for_each     = var.aws_service_gateway_endpoints
  service      = each.value
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "aws_gateway" {
  for_each          = data.aws_vpc_endpoint_service.aws_gateway
  vpc_id            = aws_vpc.this.id
  vpc_endpoint_type = "Gateway"
  service_name      = each.value.service_name
  route_table_ids   = local.route_table_ids_all

  tags = merge(
    { Name = "${var.name}-${each.key}" },
    var.tags
  )
}


# -- Interface Endpoints --------------------------------------------------------

data "aws_vpc_endpoint_service" "aws_interface" {
  for_each     = var.aws_service_interface_endpoints
  service      = each.value
  service_type = "Interface"
}


locals {

  vpce_deployment_subnets_every = [
    for k, sn in aws_subnet.routing : sn.id
    if var.routing_subnet_config[k].type == "private"
  ]

  vpce_deployment_subnets_single = [local.vpce_deployment_subnets_every[0]]

  # Construct a helper map for each az that points to a list of objects
  # {
  #   "a" => [...],
  #   "b" => [...] 
  # }
  vpce_deployment_subnets_one_per_az_map = {
    for az in local.sn_routing_private_distinct_azs : az => [
      for key, config in var.routing_subnet_config : {
        availability_zone = az,
        subnet_id         = aws_subnet.routing[key].id
      }
      if config.availability_zone == az
    ]
  }
  vpce_deployment_subnets_one_per_az = [for v in local.vpce_deployment_subnets_one_per_az_map : v[0].subnet_id if length(v) > 0]

  vpce_deployment_subnets = {
    None        = [],
    Single      = local.vpce_deployment_subnets_single,
    OnePerAz    = local.vpce_deployment_subnets_one_per_az
    EverySubnet = local.vpce_deployment_subnets_every
  }
}


resource "aws_vpc_endpoint" "aws_interface" {
  for_each = {
    for k, v in data.aws_vpc_endpoint_service.aws_interface : k => v
    if var.aws_service_interface_deployment_type != "None"
  }
  vpc_id              = aws_vpc.this.id
  vpc_endpoint_type   = "Interface"
  service_name        = each.value.service_name
  subnet_ids          = local.vpce_deployment_subnets[var.aws_service_interface_deployment_type]
  private_dns_enabled = true

  tags = merge(
    { Name = "${var.name}-${each.key}" },
    var.tags
  )
}
