#VPC
variable "region" { type = string }
variable "project_name" { type = string }
variable "vpc_cidr" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }

#EC2 
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "key_name" { type = string } 

#route53
variable "domain_name" { type = string } 


