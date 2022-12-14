
variable "vpc_id" {
  type = string
}

variable "vpc_ipv4_cidr" {
  type = string
}

variable "vpc_ipv6_cidr" {

}

variable "name" {
  type = string
}

variable "subnet_config" {
  type = map(object({
    ipv4 = object({ cidr = number, index = number })
    ipv6 = object({ cidr = number, index = number })
  }))
}


variable "availability_zone" {
  type     = string
  nullable = true
  default  = null
}

variable "routes" {
  type = map(object({
    type    = string,
    id      = string,
    cidr_v4 = optional(string)
    cidr_v6 = optional(string)
  }))
}

