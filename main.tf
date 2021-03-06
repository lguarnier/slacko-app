data "aws_ami" "slacko-app" {
    most_recent = true
    owners = ["amazon"]
 
    filter {
        name = "name"
        values = ["Amazon*"]
    }

    filter {
        name = "architecture"
        values = ["x86_64"]
    }

}

data "aws_subnet" "subnet_public" {
   cidr_block = "10.0.102.0/24"
}

# Gerando a chave
# ssh-keygen -C slacko -f slacko
resource "aws_key_pair" "slacko-sshkey" {
    key_name = "slacko-app-key"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCnQQQyA7nhlgcD02fLpZKyUO2TG4i8m7XiR7AZf5BUX+HyKAoh4Zll5HsPhtF2ZAEbHRLtdpOCrCAKqZnWVsQtZoqKUG1gF66ilBruR3MbSgOpNi+ejbsZNOotzKDrNCM6m6qgfGTQewV3Ey/7IJ0fP8vwOYivRXShMHatqTSAIAJRVYV5s6XJlcOlYjStJdsdwNHt14xpfeQWczSXV6McL8fy+nEJdS71bVhCusrBkaDP/YRmD2U/k1x2Izhy+EyoQQqtkSUHN2L5XIEXAbomvFydv9M1t/U8KJG39YZTcu9r4FgxLAa1NurlhQLyyys2wotmym1tXyZrSthcBeZLAuhFmTsWfo2m1YkFVr7fghzKqXQrqEpDDWDQdedARSJfI1+SRZ/DXvYoC42CcHwZtdYJKZXNVKr9edIw9YjEQ5sFgjkRK/aEEKsn64q/uFnP9dkuro4s2RvHyv6B6NNlSOSAZOrVP82b0ZIhRPBUv1qlVpRtZnMMpSLOSdf3hkU= slacko"
}

resource "aws_instance" "slacko-app" {
    ami = data.aws_ami.slacko-app.id
    instance_type = "t2.micro"
    subnet_id = data.aws_subnet.subnet_public.id
    associate_public_ip_address = true

    tags = {
        Name = "slacko-app"
    }

    key_name = aws_key_pair.slacko-sshkey.id

    # arquivo de bootstrap  
    user_data = file("ec2.sh")
}

resource "aws_instance" "mongodb" {
    ami = data.aws_ami.slacko-app.id
    instance_type = "t2.small"
    subnet_id = data.aws_subnet.subnet_public.id

    tags = {
        Name = "mongodb"

    }
    key_name = aws_key_pair.slacko-sshkey.id
    user_data = file("mongodb.sh")
}

resource "aws_security_group" "allow-slacko" {
    name = "allow_ssh_http"
    description = "Allow ssh and http port"
    vpc_id = "vpc-0d6d4d19a8372e09c"

    ingress =[
    {
        description = "Allow SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    },
    {
        description = "Allow Http"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]

    egress = [
    {
        description = "Allow all"
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]

 tags = {
  Name = "allow_ssh_http"
 }
}

resource "aws_security_group" "allow-mongodb" {
    name = "allow_mongodb"
    description = "Allow MongoDB"
    vpc_id = "vpc-0d6d4d19a8372e09c"

    ingress = [
    {
        description = "Allow MongoDB"
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]
    egress = [
    {
        description = "Allow all"
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]

    tags = {
        Name = "allow_mongodb"
  }
}

resource "aws_network_interface_sg_attachment" "mongodb-sg" {
   security_group_id = aws_security_group.allow-mongodb.id
   network_interface_id = aws_instance.mongodb.primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "slacko-sg" {
   security_group_id = aws_security_group.allow-slacko.id
   network_interface_id = aws_instance.slacko-app.primary_network_interface_id
}

resource "aws_route53_zone" "slack_zone" {
  name = "iaac0506.com.br"
  vpc {
    vpc_id = "vpc-0d6d4d19a8372e09c"
  }
}

resource "aws_route53_record" "mongodb" {
    zone_id = aws_route53_zone.slack_zone.id
    name = "mongodb.iaac0506.com.br"
    type = "A"
    ttl = "300"
    records = [aws_instance.mongodb.private_ip]
}
