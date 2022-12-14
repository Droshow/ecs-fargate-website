variable "site_domain" {
  type        = string
  description = "The site domain name to configure (without any subdomains such as 'www')"
}

variable "site_name" {
  type        = string
  description = "The unique name for this instance of the module. Required to deploy multiple ghost instances to the same AWS account (if desired)."
  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^[0-9A-Za-z]+$", var.site_name))
    error_message = "For site_name value only a-z, A-Z and 0-9 are allowed."
  }
}
variable "s3_region" {
  type        = string
  description = "The regional endpoint to use for the creation of the S3 bucket for published static ghost site."
}




############################
# Cluster ECS
############################

variable "cluster_name" {
  description = "Name of the cluster (up to 255 letters, numbers, hyphens, and underscores)"
  type        = string
  default     = ""
}

variable "cluster_configuration" {
  description = "The execute command configuration for the cluster"
  type        = any
  default     = {}
}

variable "cluster_settings" {
  description = "Configuration block(s) with cluster settings. For example, this can be used to enable CloudWatch Container Insights for a cluster"
  type        = map(string)
  default = {
    name  = "containerInsights"
    value = "enabled"
  }
}

############################
# Capacity Providers ECS
############################

variable "default_capacity_provider_use_fargate" {
  description = "Determines whether to use Fargate or autoscaling for default capacity provider strategy"
  type        = bool
  default     = true
}

variable "fargate_capacity_providers" {
  description = "Map of Fargate capacity provider definitions to use for the cluster"
  type        = any
  default     = {}
}

############################
# CloudFront
############################

variable "cloudfront_aliases" {
  type        = list(any)
  description = "The domain and sub-domain aliases to use for the cloudfront distribution."
  default     = []
}

variable "cloudfront_class" {
  type        = string
  description = "The [price class](https://aws.amazon.com/cloudfront/pricing/) for the distribution. One of: PriceClass_All, PriceClass_200, PriceClass_100"
  default     = "PriceClass_All"
}

variable "hosted_zone_id" {
  type        = string
  description = "The Route53 HostedZone ID to use to create records in."
}

variable "waf_enabled" {
  type        = bool
  description = "Flag to enable default WAF configuration in front of CloudFront."
}
