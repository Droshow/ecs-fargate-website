output "cloudfront_domain_name" {
  value       = module.cloudfront.cloudfront_domain_name
  description = "The domain name corresponding to the CloudFront distribution"
}
