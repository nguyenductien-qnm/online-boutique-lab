variable "aws_region" {
  description = "AWS region containing the ECR repositories."
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
  default     = "default"
}

variable "repository_prefix" {
  description = "Common namespace for service repositories."
  type        = string
  default     = "online-boutique"

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.repository_prefix))
    error_message = "repository_prefix must be a valid lowercase ECR repository path."
  }
}

variable "services" {
  description = "Microservices receiving one ECR repository each."
  type        = set(string)
  default = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice",
    "shoppingassistantservice",
  ]

  validation {
    condition = alltrue([
      for service in var.services : can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*$", service))
    ])
    error_message = "Every service name must be a valid lowercase ECR repository component."
  }
}

variable "tags" {
  description = "Tags applied to every ECR repository."
  type        = map(string)
  default = {
    Application = "online-boutique"
    ManagedBy   = "Terraform"
  }
}
