#########
#S3
#########
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "static_content" {
  bucket = "static-content-${var.site_name}"
  acl    = "private"
}

resource "aws_cloudfront_origin_access_identity" "s3_oai" {
  comment = "S3 OAI for static content"
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.static_content.id}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.s3_oai.iam_arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "static_content" {
  bucket = aws_s3_bucket.static_content.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

#########
#Cloudfront
#########

# locals {
#   s3_origin_id = var.tag
# }
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.static_content.bucket_regional_domain_name
    origin_id   = "S3_static_content"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_oai.cloudfront_access_identity_path
    }
    # origin_path = "/static/*"
  }

  origin {
    domain_name = var.alb_domain
    origin_id   = "ALB_dynamic_content"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }


  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3_static_content"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/dynamic/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "ALB_dynamic_content"

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cloudfront_certificate.arn
    ssl_support_method   = "sni-only"
  }
}

# ROUTE53
data "aws_route53_zone" "main" {
  name = var.dns_domain
}
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.dns_record
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# ACM
resource "aws_acm_certificate" "cloudfront_certificate" {
  domain_name = "*.${var.dns_domain}"
  validation_method = "DNS"
  tags = {
    Name = "CloudFront Certificate"
  }
  provider = aws.us_east_1
}

# resource "aws_acm_certificate" "copy" {
#   certificate_arn = data.aws_acm_certificate.cloudfront_certificate.arn
#   region          = "us-east-1"
# }

resource "aws_route53_record" "acm_validation" {
  count   = length(aws_acm_certificate.cloudfront_certificate.domain_validation_options)
  name    = element(aws_acm_certificate.cloudfront_certificate.domain_validation_options.*.resource_record_name, count.index)
  type    = element(aws_acm_certificate.cloudfront_certificate.domain_validation_options.*.resource_record_type, count.index)
  zone_id = data.aws_route53_zone.main.zone_id
  records = [element(aws_acm_certificate.cloudfront_certificate.domain_validation_options.*.resource_record_value, count.index)]
  ttl     = 60
}