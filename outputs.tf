output "alb_dns_name" { value = module.compute.alb_dns_name } 
output "bucket_name" { value = module.s3.bucket_name } 
output "db_instance_endpoint" { value = module.rds.db_instance_endpoint } 
output "efs_dns_name" { value = module.compute.efs_dns_name } 
