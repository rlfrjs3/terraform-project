output "ssl_cert_arn" { value = aws_acm_certificate.ssl_cert.arn } 
output "route53_ns_records" { value = aws_route53_zone.hosting_zone.name_servers } 
