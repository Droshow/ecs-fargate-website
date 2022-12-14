variable "vpc_id" {
  type = string
}
variable "name" {
  type = string
}

variable "traffic_type" {
  type    = string
  default = "ALL"
}

variable "iam_path" {
  type    = string
  default = "/"
}

variable "retention_in_days" {
  type = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
