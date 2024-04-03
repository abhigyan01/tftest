variable "project_id" {
  type        = string
  description = "Project ID"
  default     = "plasma-outcome-417721"
}

variable "region" {
  type        = string
  description = "Region for this infrastructure"
  default     = "us-east1"
}

variable "name" {
  type        = string
  description = "Name for this infrastructure"
  default     = "accelerator-01"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnets"
  default     = "10.0.0.0/20"
}

variable "private_subnet_count" {
  description = "Number of private subnets to create"
  default     = 3
}
