terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.44"
    }
  }
  required_version = ">= 0.13"
}

provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = var.aws_region
}

locals {
  s3_origin_id = "S3-${var.bucket_name}"
}

resource "aws_s3_bucket" "hosting" {
  bucket = var.bucket_name
  acl    = "public-read"
  region = var.aws_region

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    Name        = "${var.name}-s3-hosting-${var.environment}"
    Project     = var.name
    Environment = var.environment
  }
}

output "s3_bucket_url" {
  value = aws_s3_bucket.hosting.bucket_domain_name
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Cloudfront Origin Access Identity"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.hosting.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "hosting" {
  bucket = aws_s3_bucket.hosting.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.hosting.bucket_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  comment             = "CDN for ${var.bucket_name} S3 Bucket"
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    target_origin_id = local.s3_origin_id
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }

      headers = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }
  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.tsl_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  tags = {
    Name        = "${var.name}-cdn-${var.environment}"
    Project     = var.name
    Environment = var.environment
  }
}

resource "aws_route53_record" "alias" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www-alias" {
  zone_id = var.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
