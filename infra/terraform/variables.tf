variable "aws_region" {
  description = "AWS region where the ECS/Fargate workload is deployed."
  type        = string
  default     = "us-east-1"
}

variable "stack_name" {
  description = "Base name for workload resources. The resource prefix is prepended when present."
  type        = string
  default     = "order-satellite-service"
}

variable "resource_prefix" {
  description = "Environment/resource prefix used in resource names and Terraform state derivation."
  type        = string
  default     = "aws-dev-mn"

  validation {
    condition     = var.resource_prefix == "" || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*$", var.resource_prefix))
    error_message = "resource_prefix must be empty or contain only letters, numbers, and hyphens, starting with a letter or number."
  }
}

variable "image_uri" {
  description = "Container image URI to deploy to ECS."
  type        = string
  default     = ""
}

variable "order_api_base_url" {
  description = "External order API base URL consumed by the Micronaut service."
  type        = string
}

variable "desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Container HTTP port."
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 1
}

variable "instrumentation_mode" {
  description = "Container instrumentation mode. Use javaagent to enable the baked OpenTelemetry Java agent."
  type        = string
  default     = "javaagent"

  validation {
    condition     = contains(["code", "javaagent"], var.instrumentation_mode)
    error_message = "instrumentation_mode must be one of: code, javaagent."
  }
}

variable "export_strategy" {
  description = "Telemetry export path applied to traces and metrics in the deployed container."
  type        = string
  default     = "collector"

  validation {
    condition     = contains(["collector", "direct"], var.export_strategy)
    error_message = "export_strategy must be one of: collector, direct."
  }
}

variable "collector_endpoint" {
  description = "Effective collector OTLP base endpoint."
  type        = string
  default     = ""
}

variable "collector_traces_endpoint" {
  description = "Optional collector traces endpoint override."
  type        = string
  default     = ""
}

variable "collector_metrics_endpoint" {
  description = "Optional collector metrics endpoint override."
  type        = string
  default     = ""
}

variable "direct_endpoint" {
  description = "Optional direct OTLP base endpoint for direct export mode."
  type        = string
  default     = ""
}

variable "direct_traces_endpoint" {
  description = "Optional direct traces endpoint override."
  type        = string
  default     = ""
}

variable "direct_metrics_endpoint" {
  description = "Optional direct metrics endpoint override."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID where the service will be deployed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id is required and must look like an AWS VPC ID, for example vpc-0123456789abcdef0."
  }
}

variable "app_version" {
  description = "Service version advertised through OpenTelemetry resource attributes."
  type        = string
  default     = "1.0.0"
}
