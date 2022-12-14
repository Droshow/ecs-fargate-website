# -- VPC --------------------------------------------------------

output "vpc_id" {
  description = "The id of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_ipv4" {
  description = "The ipv4 cidr block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "vpc_cidr_ipv6" {
  description = "The ipv6 cidr block of the VPC"
  value       = aws_vpc.this.ipv6_cidr_block
}


# -- Subnets --------------------------------------------------------

output "subnet_ids" {
  description = "The ids of the subnets, specified as a map with the same keys that has been provided in the `subnet_config` input."
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "public_subnet_ids" {
  description = "The ids of all the subnets of type `public`, specified as a map with the same keys that has been provided in the `subnet_config` input."
  value       = { for k, v in aws_subnet.this : k => v.id if var.subnet_config[k].type == "public" }
}

output "private_subnet_ids" {
  description = "The ids of all the subnets of type `private`, specified as a map with the same keys that has been provided in the `subnet_config` input."
  value       = { for k, v in aws_subnet.this : k => v.id if var.subnet_config[k].type == "private" }
}

output "egress_only_subnet_ids" {
  description = "The ids of all the subnets of type `egress_only`, specified as a map with the same keys that has been provided in the `subnet_config` input."
  value       = { for k, v in aws_subnet.this : k => v.id if var.subnet_config[k].type == "egress_only" }
}

output "public_routing_subnet_ids" {
  value = { for k, v in aws_subnet.routing : k => v.id if var.routing_subnet_config[k].type == "public" }
}

output "private_routing_subnet_ids" {
  value = { for k, v in aws_subnet.routing : k => v.id if var.routing_subnet_config[k].type == "private" }
}


# -- Gateways --------------------------------------------------------

output "internet_gateway_id" {
  description = "The id of the deployed internet gateway."
  value       = aws_internet_gateway.this.id
}

output "egress_only_gateway_id" {
  description = "The id of the deployed egress only gateway."
  value       = aws_egress_only_internet_gateway.this.id
}

output "nat_gateway_ids_per_az" {
  description = "value"
  value       = { for k, v in aws_nat_gateway.this : k => v.id }
}

output "endpoint_aws_service_gateway_ids" {
  description = "The ids of the deployed vpc endpoint gateways for AWS Services."
  value       = { for k, v in aws_vpc_endpoint.aws_gateway : k => v.id }
}

output "endpoint_aws_service_interface_ids" {
  description = "The ids of the deployed vpc endpoint interfaces for AWS Services."
  value       = { for k, v in aws_vpc_endpoint.aws_interface : k => v.id }
}


# -- NACLs --------------------------------------------------------

# output "nacl_public_ids" {
#   description = "The Network ACL id that is associated with public networks."
#   value       = aws_network_acl.this["public"].id
# }

# output "nacl_egress_only_id" {
#   description = "The Network ACL id that is associated with egress only networks."
#   value       = aws_network_acl.this["egress_only"].id
# }

# output "nacl_private_id" {
#   description = "The Network ACL id that is associated with private networks."
#   value       = aws_network_acl.this["private"].id
# }

# -- Routing Tables --------------------------------------------------------

locals {
  rtb_ids_public      = [for k, v in aws_route_table.public : v.id]
  rtb_ids_private     = [for k, v in aws_route_table.private : v.id]
  rtb_ids_egress      = [for k, v in aws_route_table.egress : v.id]
  rtb_ids_all_subnets = toset(concat(local.rtb_ids_public, local.rtb_ids_private, local.rtb_ids_egress))

  rtb_routing_private_ids     = [for k, v in aws_route_table.private_routing : v.id]
  rtb_routing_public_ids      = [for k, v in aws_route_table.public_routing : v.id]
  rbt_ids_all_routing_subnets = toset(concat(local.rtb_routing_private_ids, local.rtb_routing_public_ids))
}

output "route_table_ids" {
  description = ""
  value       = local.rtb_ids_all_subnets
}

output "routing_subnets_route_table_ids" {
  description = ""
  value       = local.rbt_ids_all_routing_subnets
}

output "public_route_table_ids" {
  description = "The route table id that is associated with public networks."
  value       = { for k, v in aws_route_table.public : k => v.id }
}

output "private_route_table_ids" {
  description = "The route table id that is associated with private networks."
  value       = { for k, v in aws_route_table.private : k => v.id }
}

output "egress_only_route_table_ids" {
  description = "The route table id that is associated with egress only networks."
  value       = { for k, v in aws_route_table.egress : k => v.id }
}

# -- DHCP --------------------------------------------------------

output "dhcp_options_set_id" {
  value = one(aws_vpc_dhcp_options.this[*].id)
}

output "dhcp_options_set_arn" {
  value = one(aws_vpc_dhcp_options.this[*].arn)
}


# -- Flow Logs --------------------------------------------------------


output "flow_logs" {
  value = module.vpc_flow_logs
}
