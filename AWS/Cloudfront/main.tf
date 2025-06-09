# Create S3 bucket
resource "aws_s3_bucket" "site_origin" {
  bucket = "host-website-mf37"
}

# Allow public access to bucket objects
resource "aws_s3_bucket_public_access_block" "site_origin" {
  bucket                  = aws_s3_bucket.site_origin.bucket
  block_public_acls       = false 
  block_public_policy     = false 
  ignore_public_acls      = false 
  restrict_public_buckets = false 
}

# Encrypt bucket objects/ use AES256 for each bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "site_origin" {
  bucket = aws_s3_bucket.site_origin.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable bucket versioning for accidental deletion
resource "aws_s3_bucket_versioning" "site_origin" {
  bucket = aws_s3_bucket.site_origin.bucket
  versioning_configuration { 
    status = "Enabled"
  }
}

# Add html file to bucket
resource "aws_s3_object" "content" { 
  # Create object after creating bucket
  depends_on = [
    aws_s3_bucket.site_origin
  ]
  bucket                 = aws_s3_bucket.site_origin.bucket
  key                    = "home.html"
  source                 = "home.html"
  server_side_encryption = "AES256"
  content_type           = "text/html" 
}


# Add jpg folder inside bucket/ upload jpg files using commands in terminal
resource "aws_s3_object" "jpg" { 
  depends_on = [
    aws_s3_bucket.site_origin
  ]
  bucket                 = aws_s3_bucket.site_origin.bucket
  key                    = "jpg/"
  server_side_encryption = "AES256"
  content_type           = "image/jpeg" 
}

# Use existing acm certifacte from the AWS console
data "aws_acm_certificate" "amazon_issued" {
  domain      = var.subdomain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# Create origin access identity/ point cloudfront to s3 to serve static web pages
resource "aws_cloudfront_origin_access_control" "site_access" {
  name                              = "security_pillar100_cf_s3_oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always" 
  signing_protocol                  = "sigv4"  
}

# Create cloudfront to serve static webpages
resource "aws_cloudfront_distribution" "site_access" {
  # Resource depends on the creation of your S3 bucket
  depends_on = [ 
    aws_s3_bucket.site_origin,
    aws_cloudfront_origin_access_control.site_access,
  ]
  enabled             = true      
  default_root_object = "home.html" 

  # Describes how we want cloudfront to fetch objects from s3/ redirect http traffic to https
  default_cache_behavior { 
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.site_origin.id
    viewer_protocol_policy = "redirect-to-https" 
    min_ttl                = 2                             # 10 keep following for production
    default_ttl            = 6                             # 30
    max_ttl                = 10                            # 60

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  aliases = [var.domain_name, var.subdomain_name] 
  origin {
    domain_name              = aws_s3_bucket.site_origin.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.site_origin.id
    origin_access_control_id = aws_cloudfront_origin_access_control.site_access.id
  }

  # Allow access only from USA and Canada
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA"]
    }
    
  }

  # Add tls certificate from acm console
  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.amazon_issued.id
    ssl_support_method  = "sni-only"
  }
  tags = {
    Description = "host personal website"
  }
}

# Create policy to allow cloudfront to fetch html file S3 in order to serve it 
resource "aws_s3_bucket_policy" "site_origin" {
  bucket = aws_s3_bucket.site_origin.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Sid" : "PublicReadGetObject",
      "Effect" : "Allow",
      "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
      "Action" : "s3:GetObject",
      "Resource" : "arn:aws:s3:::${aws_s3_bucket.site_origin.id}/*"
    }]
  })
}

# Create route 53 to route traffic to cloudfront/ edge locations
data "aws_route53_zone" "hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# Create records with failover policy
resource "aws_route53_record" "primary_alias" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "www.${data.aws_route53_zone.hosted_zone.name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site_access.domain_name    
    zone_id                = aws_cloudfront_distribution.site_access.hosted_zone_id
    evaluate_target_health = true
  }
  failover_routing_policy {
    type = "PRIMARY"
  }
  set_identifier = "primary"
  health_check_id = aws_route53_health_check.primary.id
}
resource "aws_route53_record" "secondary_alias" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "www.${data.aws_route53_zone.hosted_zone.name}"
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.site_access.domain_name   
    zone_id                = aws_cloudfront_distribution.site_access.hosted_zone_id 
    evaluate_target_health = true
  }
  failover_routing_policy {
    type = "SECONDARY"
  }
  set_identifier = "secondary"
  health_check_id = aws_route53_health_check.secondary.id
}

# Create health checks for both records / if primary record fails, traffic will route to secondary record 
resource "aws_route53_health_check" "primary" {
  fqdn              = "www.${data.aws_route53_zone.hosted_zone.name}"
  port              = 443
  type              = "HTTPS"
  request_interval  = 30
  failure_threshold = 3
  tags = {
    Name = "primary_health_check"
  }
}
resource "aws_route53_health_check" "secondary" {
  fqdn              = "www.${data.aws_route53_zone.hosted_zone.name}"
  port              = 443
  type              = "HTTPS"
  request_interval  = 30
  failure_threshold = 3
  tags = {
    Name = "secondary_health_check"
  }
}