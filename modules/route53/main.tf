#provider.alias 사용하기 위해 선언 필요
#terraform {
#  required_providers {
#    aws = {
#      source  = "hashicorp/aws"
#      version = ">= 6.0"
#    }
#  }
#}


###<Route53에서 호스팅영역 생성>
resource "aws_route53_zone" "kkangsoju" {
  name = var.domain_name
}


###<ACM에서 SSL인증서 생성>
resource "aws_acm_certificate" "ssl_cert" { 
  domain_name = var.domain_name   #SSL 인증서의 도메인 이름
  subject_alternative_names = ["www.kkangsoju.co.kr"]    #추가적인 대체 도메인 이름
  validation_method = "DNS"
  lifecycle { create_before_destroy = true }   #인증서 갱신 시 먼저 새 인증서를 생성한 후, 기존 인증서를 제거
}




###<SSL 인증서 DNS인증 자동화>
#검증을 위한 DNS레코드 받아오기
resource "aws_route53_record" "ssl_cert_record" { 
  for_each = {
    for dvo in aws_acm_certificate.ssl_cert.domain_validation_options : dvo.domain_name => { 
      name = dvo.resource_record_name             #검증을 위한 레코드 이름
      type = dvo.resource_record_type             #검증을 위한 레코드 유형
      record = dvo.resource_record_value          #검증을 위한 레코드 값
    }
  }
#위에서 받아온 레코드 내 도메인에 적용해서 인증하기
zone_id = aws_route53_zone.kkangsoju.zone_id
name = each.value.name
type = each.value.type
records = [each.value.record]
ttl = 300 
}

#실제 SSL인증서 검증 프로세스
resource "aws_acm_certificate_validation" "ssl_cert_validation" { 
  certificate_arn = aws_acm_certificate.ssl_cert.arn     #위 ACM에서 생성한 SSL인증서 
  validation_record_fqdns = [for record in aws_route53_record.ssl_cert_record : record.fqdn]  #위 검증을 위해 생성한 DNS레코드 
}







###<DNS 레코드에 cloudfront 배포 레코드 설정하기>
resource "aws_route53_record" "root__domain" {   #대포도메인 레코드 설정
  zone_id = aws_route53_zone.kkangsoju.zone_id
  name = var.domain_name
  type = "A"
  alias {
    name = var.cloudfront_domain_name
    zone_id = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_domain" {  #www 서브도메인 레코드 설정
  zone_id = aws_route53_zone.kkangsoju.zone_id
  name = "www.${var.domain_name}"
  type = "A"
  alias {
    name = var.cloudfront_domain_name
    zone_id = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}



#필요한 수동 작업 : 개인 도메인 NS 레코드 설정 (호스팅영역 생성할 때마다 NS 레코드가 바뀌기 때문에)

