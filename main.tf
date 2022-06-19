 resource "aws_vpc" "Main" {                # Creating VPC here
   cidr_block       = var.main_vpc_cidr     # Defining the CIDR block use 10.0.0.0/24
   enable_dns_hostnames = true
 }

 resource "aws_internet_gateway" "IGW" {    # Creating Internet Gateway
    vpc_id =  aws_vpc.Main.id               # vpc_id will be generated after we create VPC
 }

 resource "aws_subnet" "publicsubnets" {    # Creating Public Subnets
   vpc_id =  aws_vpc.Main.id
   cidr_block = "${var.public_subnets}"        # CIDR block of public subnets
 }

 resource "aws_subnet" "privatesubnets" {            # Creating Private Subnets
   vpc_id =  aws_vpc.Main.id
   cidr_block = "${var.private_subnets}"          # CIDR block of private subnets
 }

 resource "aws_route_table" "PublicRT" {    # Creating RT for Public Subnet
    vpc_id =  aws_vpc.Main.id
         route {
    cidr_block = "0.0.0.0/0"               # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.IGW.id
     }
 }

 resource "aws_route_table" "PrivateRT" {    # Creating RT for Private Subnet
   vpc_id = aws_vpc.Main.id
  }


resource "aws_security_group" "allow_tls" {        #allow_tls costum of any port needed
  name        = "80_443"
  description = "Allow 80_443 inbound traffic"
  vpc_id =  aws_vpc.Main.id
  tags = {
    Name =  "80_443"
}
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port           = 443
    to_port             = 443
    protocol            = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "my-webserver-1" {
  ami           = "ami-065deacbcaac64cf2"                     # eu-central-1
  instance_type = "t2.micro"
  security_groups =  ["80_443"]

user_data = <<EOF
#! /bin/bash
                sudo apt-get update
                sudo apt-get install -y apache2
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo "<h1>Web-server1</h1>" | sudo tee /var/www/html/index.html
EOF
}
resource "aws_instance" "my-webserver-2" {
  ami           = "ami-065deacbcaac64cf2"                     # eu-central-1
  instance_type = "t2.micro"
   security_groups =  ["80_443"]
user_data = <<EOF
        #! /bin/bash
        sudo apt-get update
        sudo apt-get install -y apache2
        sudo systemctl start apache2
        sudo systemctl enable apache2
        echo "<h1>Web-server2</h1>" | sudo tee /var/www/html/index.html
   EOF
}



resource "aws_elb" "my_elb" {
security_groups = ["${aws_security_group.allow_tls.id}"]
 subnets = ["${aws_subnet.publicsubnets.id}"]


#listener {
#    instance_port      = 443
#    instance_protocol  = "tcp"
#    lb_port            = 443
#    lb_protocol        = "ssl"
#    ssl_certificate_arns = [
#      "${aws_iam_server_certificate.domain.arn}",

 #   ]

 # }
listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
instances                     =  ["${aws_instance.my-webserver-1.id}","${aws_instance.my-webserver-2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

}
resource "aws_route53_zone" "myZone" {
  name = "test.com"

}

resource "aws_route53_record" "myRecord" {
  zone_id = aws_route53_zone.myZone.zone_id
  name    = "www.test.com"
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.my_elb.dns_name]
}
