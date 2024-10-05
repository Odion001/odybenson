terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Create an S3 bucket for the static website
resource "aws_s3_bucket" "static_website_bucket" {
  bucket = "refinersfire112" # Replace with a unique bucket name
}

# Configure the bucket for website hosting
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.static_website_bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Set object ownership controls to 'BucketOwnerEnforced'
resource "aws_s3_bucket_ownership_controls" "ownership_controls" {
  bucket = aws_s3_bucket.static_website_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Manage public access settings for the S3 bucket (allow public policies)
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.static_website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Upload files to the S3 bucket
resource "aws_s3_object" "website_files" {
  for_each = fileset("/Users/peterokoruwa/Downloads/bootcamp-1-project-1a-main", "**")

  bucket = aws_s3_bucket.static_website_bucket.bucket
  key    = each.value
  source = "/Users/peterokoruwa/Downloads/bootcamp-1-project-1a-main/${each.value}"

  content_type = lookup(
    {
      ".html" = "text/html"
      ".css"  = "text/css"
      ".js"   = "application/javascript"
      ".png"  = "image/png"
      ".jpg"  = "image/jpeg"
      ".jpeg" = "image/jpeg"
      ".gif"  = "image/gif"
      ".txt"  = "text/plain"
    },
    (length(regexall("\\.[^.]+$", each.value)) > 0) ? regexall("\\.[^.]+$", each.value)[0] : ".txt",
    "application/octet-stream"
  )
}

# S3 bucket policy to allow public read access
resource "aws_s3_bucket_policy" "static_website_policy" {
  bucket = aws_s3_bucket.static_website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.static_website_bucket.arn}/*"
      }
    ]
  })
}

# CloudFront distribution to serve the website globally
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.static_website_bucket.bucket_regional_domain_name
    origin_id   = "S3-Origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Origin"

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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Output the CloudFront distribution domain name (URL)
output "cloudfront_url" {
  description = "The CloudFront distribution domain name (URL)"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}