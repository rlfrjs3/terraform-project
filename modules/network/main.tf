###<VPC>
resource "aws_vpc" "tf-vpc" { 
  cidr_block = var.vpc_cidr
  enable_dns_support = true     #DNS 사용 허용
  enable_dns_hostnames = true   #퍼블릭IP를 가진 인스턴스가 퍼블릭DNS 이름을 자동으로 할당받도록 

  tags = { Name = "${var.project_name}-vpc" } 
}




###<서브넷>
#퍼블릭 서브넷 (각 AZ당 하나씩)
resource "aws_subnet" "public" { 
  count = length(var.availability_zones)
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = var.public_subnet_cidrs[count.index]  #각각의 퍼블릭 서브넷에 퍼블릭 대역대가 지정
  availability_zone = var.availability_zones[count.index]  #퍼블릭 서브넷이 각각의 AZ에 할당 

  map_public_ip_on_launch = true    #퍼블릭 서브넷에 인스턴스를 띄울 때 퍼블릭IP 자동할당
  
  tags = { Name = "${var.project_name}-public-subnet-${count.index + 1}" }
}

#프라이빗 서브넷 (각 AZ당 하나씩)
resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = var.private_subnet_cidrs[count.index]  #각각의 프라이빗 서브넷에 프라이빗 대역대가 지정
  availability_zone = var.availability_zones[count.index]  #프라이빗 서브넷이 각각의 AZ에 할당

  tags = { Name = "${var.project_name}-private-subnet-${count.index + 1}" }
}




###<인터넷 게이트웨이>
resource "aws_internet_gateway" "tf-igw" { 
  vpc_id = aws_vpc.tf-vpc.id
  
  tags = { Nmae = "{var.project_name}-igw}" }
}




###<라우팅테이블>
#(프라이빗은 라우팅테이블은 안만들어도 됨. 기본적으로 AWS  라우팅테이블은 VPC내 통신은 가능함)#

#퍼블릭 라우팅테이블
resource "aws_route_table" "public" { 
  vpc_id = aws_vpc.tf-vpc.id
  route { 
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }
  
  tags = { Name = "${var.project_name}-public-rt" } 
}

#퍼블릭 서브넷에 퍼블릭 라우팅테이블 연결
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}




###<Security Group>
#WEB 보안그룹 
resource "aws_security_group" "web" { 
  vpc_id = aws_vpc.tf-vpc.id
  
  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["106.246.242.226/32"]
  }

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 443
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol = "-1"   #모든 프로토콜 허용
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-web-sg" } 
}

#DB 보안그룹
resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.tf-vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 3306    
    to_port     = 3306
    security_groups = [aws_security_group.web.id]      # 웹서버 보안그룹에서의 접근 허용
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}


#EFS 보안그룹
resource "aws_security_group" "efs" { 
  vpc_id = aws_vpc.tf-vpc.id 
  
  ingress { 
    protocol = "tcp"
    from_port = 2049
    to_port = 2049
    security_groups = [aws_security_group.web.id]  
  }

  egress { 
    protocol = "-1"
    from_port = 0
    to_port = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "${var.project_name}-efs-sg" } 
}
    





