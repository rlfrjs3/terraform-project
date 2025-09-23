###<버전 및 프로바이더 설정>
terraform { 
  required_version = ">= 1.5.0"   #테라폼 CLI 최소버전 요구 명시
  required_providers {   #테라폼 프로바이더 종류와 버전 명시
    aws = {
      source = "hashicorp/aws"  
      version = ">= 6.0" 
    }
  }
}



###< 리전>

#공통 리전
provider "aws" { region = var.region }

#cloudfront에 ACM SSL 인증서 연결을 위해서는 us-east-1 리전에서 인증서를 발급해야 함(인증서를 해당 리전에서 중앙 관리하기 때문에)
provider "aws" { 
  alias = "us_east_1"
  region = "us-east-1"    
}



###<각 모듈별 변수 참조>
module "network" {
  source = "./modules/network"    
  project_name = var.project_name   
  vpc_cidr = var.vpc_cidr  
  availability_zones = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "compute" { 
  source = "./modules/compute"
  project_name = var.project_name
  vpc_id = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  web_sg_id = module.network.web_sg_id  
  efs_sg_id = module.network.efs_sg_id  
  ami_id = var.ami_id     
  instance_type = var.instance_type
  key_name = var.key_name
}

module "s3" {
  source = "./modules/s3"
  project_name = var.project_name
}

module "rds" {
  source = "./modules/rds"
  project_name = var.project_name
  private_subnet_ids = module.network.private_subnet_ids
  rds_sg_id = module.network.rds_sg_id
}

module "cloudfront" { 
  source = "./modules/cloudfront"
 #providers = { aws = aws.us_east_1 }   #cloudfront는 글로벌 리소스이기 때문에 필요없음
  project_name = var.project_name
  alb_dns_name = module.compute.alb_dns_name
  ssl_cert_arn = module.route53.ssl_cert_arn
  domain_name = var.domain_name
  bucket_domain_name = module.s3.bucket_domain_name
}

module "route53" {
  source = "./modules/route53"
  providers = { aws = aws.us_east_1 }   #provider.alias 리전 지정
  domain_name = var.domain_name
  cloudfront_domain_name = module.cloudfront.cloudfront_domain_name
  cloudfront_hosted_zone_id = module.cloudfront.cloudfront_hosted_zone_id
}







#! 해당 테라폼 apply할 때마다 개인 도메인 NS 레코드를 콘솔에서 확인해서 수정해줘야 함 
#->호스팅영역 생성/삭제할 때마다, NS 레코드가 바뀌기 때문에
#->안바꿔주면 ACM SSL 인증서 DNS 인증이 안됨
