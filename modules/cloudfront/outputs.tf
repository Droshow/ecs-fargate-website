output "ghost_bucket_id" {
  value = aws_s3_bucket.ghost_bucket.id
}

output "ghost_bucket_arn" {
  value = aws_s3_bucket.ghost_bucket.arn
}

output "ghost_cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.ghost_distribution.domain_name
}

output "ghost_cloudfront_distrubtion_hostedzone_id" {
  value = aws_cloudfront_distribution.ghost_distribution.hosted_zone_id
}
