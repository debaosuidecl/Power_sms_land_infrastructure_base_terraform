variable "subnet_prefix"{
  description = "subnet values"
}
variable "availability_zone"{
    description = "availability regions"
}

variable "access_key"{
    description = "accessing the cloud"
}
variable "secret_key"{
    description = "secret_key"
}



provider "aws" {
  region = "us-east-1"
  access_key= var.access_key
  secret_key= var.secret_key
}

# CREATE VPC

resource "aws_vpc" "powersmsland" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name="powersmsland"
  }
} 


resource "aws_internet_gateway" "gw" { #create a gatewauy so our vpc can be able to access the intenet
  vpc_id = aws_vpc.powersmsland.id
}

# create a route table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.powersmsland.id

  route  {
      cidr_block = "0.0.0.0/0" # make all ip ranges in our subnet accessible to our internet gateway ipv4
      gateway_id = aws_internet_gateway.gw.id 
    }
  route {
      ipv6_cidr_block        = "::/0" #make all ip ranges in our subnet accessible to our internet gateway ipv6
      gateway_id = aws_internet_gateway.gw.id
    }
  

  tags = {
    Name = "powersmsland"
  }
}

# create subnet where our web server resides




resource "aws_subnet" "subnet-1"{

  vpc_id = aws_vpc.powersmsland.id

  cidr_block = var.subnet_prefix
  availability_zone = var.availability_zone

  tags = {
    Name = "powersmsland_subnet"
  }
  
}


# associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt.id
}


# create a security group to enable 22 443 and 80 ports to be available

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.powersmsland.id

  ingress  {
      description      = "HTTPS TRAFFIC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"  #tcp is web protocol
      cidr_blocks      = ["0.0.0.0/0"]
     
    }
  ingress  {
      description      = "HTTP TRAFFIC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
     
    }
  ingress {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
     
    }
  

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "webserver-intfc" {  # create a network interface and we assign a private ip to our VPC
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

resource "aws_eip" "eip" { # we assign a public ip to our VPC and link it to our private IP. basically exposing it to internet connection
  vpc                       = true # it is in a vpc (the elastic ip)
  network_interface         = aws_network_interface.webserver-intfc.id
  associate_with_private_ip = "10.0.1.50"
  depends_on =  [aws_internet_gateway.gw] # this is because eip is dependent on IG but terraform doesn't know that by default
}

output "server_public_ip" {
  value = aws_eip.eip.public_ip 
}
# create ubunt server

resource "aws_instance" "web_server_instance"{
    ami = "ami-0747bdcabd34c712a"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "main"
    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.webserver-intfc.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo bash -c 'echo "const deba=\"232\"; console.log(deba)" > /home/ubuntu/me.js'
                sudo apt update -y
                sudo apt install nodejs -y
                sudo apt install npm -y
                sudo apt install git -y
                sudo npm i -g pm2 -y
                sudo pm2 start /home/ubuntu/me.js
                EOF
    tags = {
      Name = "web-server"
    }
}



