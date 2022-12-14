# -- vars --------------------------------------------------------

variable "name" {
  type = string
}


variable "cidr_block_ipv4" {
  description = "IPv4 cidr block to use, must be private address range, e.g. 10.0.0.0/16"
  type        = string
}

variable "nat_deployment" {
  description = "Option how to deploy the NAT gateways. Could be: None|Single|OnePerAz"
  type        = string
  default     = "Single"

  validation {
    error_message = "NAT deployment type must be one of: None|Single|OnePerAz"
    condition     = contains(["None", "Single", "OnePerAz"], var.nat_deployment)
  }
}

variable "aws_service_gateway_endpoints" {
  description = "AWS services where a Gateway endpoint will be deployed in form of additional entries to the route tables in every subnet."
  type        = set(string)
  default     = ["s3", "dynamodb"]
}

variable "aws_service_interface_endpoints" {
  description = <<EOT
    AWS service where Interface endpoint will be deployed to the PRIVATE ROUTING subnets. 
    The deployment style can be configured with `aws_service_interface_deployment_type` variable.
  EOT
  type        = set(string)
  default     = []
}

variable "aws_service_interface_deployment_type" {
  description = "How interface endpoints should be deployed. Can be one of None|Single|OnePerAz|EverySubnet."
  type        = string
  default     = "OnePerAz"

  validation {
    error_message = "VPC endpoint deplyoment type must be one of: None|Single|OnePerAz|EverySubnet"
    condition     = contains(["None", "Single", "OnePerAz", "EverySubnet"], var.aws_service_interface_deployment_type)
  }
}

variable "subnet_config" {
  description = "Subnet configuration"
  type = map(object({
    ipv4              = object({ cidr = number, index = number })
    ipv6              = object({ cidr = number, index = number })
    type              = string // public, private or egress_only
    availability_zone = string
  }))
}

variable "subnet_private_dns_hostname_type_on_launch" {
  type    = string
  default = "resource-name" # or "ip-name"
  validation {
    condition     = contains(["ip-name", "resource-name"], var.subnet_private_dns_hostname_type_on_launch)
    error_message = "The provided must be either 'ip-name' or 'resource-name'."
  }
}

# -- Routing Config --------------------------------------------------------

variable "routing_subnet_config" {
  description = "value"
  type = map(object({
    ipv4              = object({ cidr = number, index = number })
    ipv6              = object({ cidr = number, index = number })
    type              = string // public, private or egress_only
    availability_zone = string
  }))
  default = {
    "routing_private_a" = { ipv4 = { cidr = 24, index = -1 }, ipv6 = { cidr = 64, index = -1 }, availability_zone = "a", type = "private" },
    "routing_private_b" = { ipv4 = { cidr = 24, index = -2 }, ipv6 = { cidr = 64, index = -2 }, availability_zone = "b", type = "private" },
    "routing_public_a"  = { ipv4 = { cidr = 24, index = -3 }, ipv6 = { cidr = 64, index = -3 }, availability_zone = "a", type = "public" },
    "routing_public_b"  = { ipv4 = { cidr = 24, index = -4 }, ipv6 = { cidr = 64, index = -4 }, availability_zone = "b", type = "public" },
  }
}


# -- Flow Logs --------------------------------------------------------

variable "flow_log_enabled" {
  description = "If flowlogs should be enabled"
  type        = bool
  default     = false
}

variable "flow_log_config" {
  description = "Additional configuration to configure flowlogs to cloudwatch"
  type = object({
    log_group_name    = string
    retention_in_days = number
    traffic_type      = string
  })

  default = {
    log_group_name    = ""
    retention_in_days = 3
    traffic_type      = "ALL"
  }

  validation {
    error_message = <<EOT
    Invalid retenetion time for the flow logs specified. Must be one of 
    
        1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    
    but was ${var.flow_log_config.retention_in_days}
    EOT
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_log_config.retention_in_days)
  }
}


# -- Tagging --------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "extra_tags_vpc" {
  description = "Extra tags to apply to the VPC"
  type        = map(string)
  default     = {}
}

variable "extra_tags_subnets" {
  description = "Extra tags to apply to all subnets"
  type        = map(string)
  default     = {}
}

variable "extra_tags_routing_subnets" {
  description = "Extra tags to apply to all routing subnets"
  type        = map(string)
  default     = {}
}

variable "extra_tags_routing_tables" {
  description = "Extra tags to apply to all routing tables"
  type        = map(string)
  default     = {}
}

variable "extra_tags_nat" {
  description = "Extra tags to apply to all NATs"
  type        = map(string)
  default     = {}
}


# -- DHCP --------------------------------------------------------

variable "dhcp_domain_name" {
  description = "An additional internal domain name that is provided via the DHCP server."
  type        = string
  nullable    = true
  default     = null
}
