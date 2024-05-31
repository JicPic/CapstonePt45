variable "host_os" {
  type    = string
  default = "windows"
}

variable "cidr_block_RB_Public_Subnet1" {
  default = "10.0.1.0/24" #Public Subnet-1
}

variable "CIDR_BLOCK" {
  default = "0.0.0.0/0" #Public CIDR
}

variable "AWS_REGION" {
  default     = "eu-central-1"
  description = "AWS Region"
}

variable "availability_zone_1" {
  description = "The first availability zone to use for resources."
  type        = string
}

variable "availability_zone_2" {
  description = "The second availability zone to use for resources."
  type        = string
}

variable "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  type        = string
  default     = "" # You can use a placeholder or empty string here
}
