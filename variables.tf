variable "name" {
  description = "the name of your stack, e.g. \"demo\""
  type        = string
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
  default     = "prod"
}

variable "aws_region" {
  description = "the AWS region in which resources are created"
  type        = string
  default     = "eu-central-1"
}

variable "aws_access_key_id" {
  description = "the AWS access key id to use for terraform operations"
  type        = string
}

variable "aws_secret_access_key" {
  description = "the secret key for the AWS access key"
  type        = string
}

variable "bucket_name" {
  description = "name of the S3 bucket"
  type        = string
}

variable "domain_name" {
  description = "which domain the hosted website will be available from"
  type        = string
}

variable "zone_id" {
  description = "id of the hosted zone where the alias records will be created"
  type        = string
}

variable "tsl_certificate_arn" {
  description = "The ARN of the certificate that Cloudfront uses for https (must be in region us-east-1)"
  type        = string
}
