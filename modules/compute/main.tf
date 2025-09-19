###<EFS>
#EFS 파일시스템 생성
resource "aws_efs_file_system" "web-efs" {
  creation_token = "${var.project_name}-efs"    #중복생성 방지용 토큰
  encrypted = true    #저장되는 데이터는 AWS KMS를 이용해 암호화
  tags = { Name = "${var.project_name}-efs" } 
}

#EFS 마운트타겟 생성 - 각 퍼블릭 서브넷마다
resource "aws_efs_mount_target" "web-efs-mt" { 
  count = length(var.public_subnet_ids)  #퍼블릭 서브넷마다 생성
  file_system_id = aws_efs_file_system.web-efs.id   
  subnet_id = element(var.public_subnet_ids, count.index)
  security_groups = [var.efs_sg_id]
}



###<Auto Scaling Group>
#시작 템플릿
resource "aws_launch_template" "web" {
  name          = "${var.project_name}-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.web_sg_id]
  depends_on = [aws_efs_mount_target.web-efs-mt]
  user_data = base64encode(<<EOT
#!/bin/bash
yum -y update && yum -y install httpd 
yum -y install amazon-efs-utils
systemctl enable --now httpd
echo "<h1>Welcome to My Web Server</h1>" > /var/www/html/index.html

mkdir -p /data/efs
echo "${aws_efs_file_system.web-efs.id}:/ /data/efs efs defaults,_netdev,nofail 0 0" >> /etc/fstab
for i in {1..12}; do 
  mount -a && break
  echo "[$(date)] Retry $i: EFS not ready yet" >> /var/log/efs-mount.log
  sleep 10 
done 

if mountpoint -q /data/efs; then
  echo "[$(date)] EFS mount Successful" >> /var/log/efs-mount.log
else
  echo "[$(date)] EFS mount fail" >> /var/log/efs-mount.log
fi
EOT
)

  tags = { Name = "${var.project_name}-web-server" }
}

#시작 템플릿을 사용하여 ASG를 생성
resource "aws_autoscaling_group" "web_asg" { 
  
  target_group_arns = [aws_lb_target_group.web_tg.arn]  #ALB 타겟그룹과 연결
  desired_capacity = 4  #평상시 갯수
  max_size = 5   #최대 갯수
  min_size = 4   #최소 갯수
  vpc_zone_identifier = var.public_subnet_ids  #퍼블릭 서브넷에만 생성
  launch_template { 
    id = aws_launch_template.web.id
    version = "$Latest"
  }
  tag {
    key = "Name"
    value = "${var.project_name}-web-server"
    propagate_at_launch = true
  }
}




###<Application Load Balancer>

#ALB 
resource "aws_lb" "web_alb" { 
  name = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups = [var.web_sg_id]
  subnets = var.public_subnet_ids 
  
  tags = { Name = "${var.project_name}-alb" } 
}

#ALB 타겟그룹
resource "aws_lb_target_group" "web_tg" { 
  name = "${var.project_name}-tg"
  port = 80
  protocol ="HTTP"
  vpc_id = var.vpc_id

  health_check {  
    path = "/"       #루트 경로로 HTTP 체
    interval = 30    #30초마다 체크
    timeout = 5      #응답대기 5초
    healthy_threshold = 2    #2번 연속 성공해야 정상으로 판단
    unhealthy_threshold = 2  #2번 연속 실패하면 비정상으로 판단
  }
  
  tags = { Name = "${var.project_name}-tg" }
}

#ALB 리스너(리스너를 통해 요청을 타겟그룹으로 전달)
resource "aws_lb_listener" "http" { 
  load_balancer_arn = aws_lb.web_alb.arn
  port = 80
  protocol = "HTTP"
  
  default_action {
    type = "forward"    #요청을 아래에서 지정한 타겟그룹으로 전달
    target_group_arn = aws_lb_target_group.web_tg.arn  
  }
}
  












# 트래픽-> ALB -> 리스너-> ALB 타겟그룹=ASG 타겟그룹  즉, ASG의 타겟그룹을 ALB 타겟그룹으로 설정
# ALB 리스너는 http 80 트래픽 통신만 받아서 처리 

