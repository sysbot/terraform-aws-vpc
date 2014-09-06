provider "aws" {
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "eu-west-1"
}

resource "aws_vpc" "default" {
	cidr_block = "10.19.0.0/16"
	enable_dns_support = true
	enable_dns_hostnames = true
}

resource "aws_internet_gateway" "default" {
	vpc_id = "${aws_vpc.default.id}"
}

# Public subnets
resource "aws_subnet" "eu-west-1a-public" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.19.8.0/21"
	availability_zone = "eu-west-1a"
}

resource "aws_subnet" "eu-west-1b-public" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.19.16.0/21"
	availability_zone = "eu-west-1b"
}

resource "aws_subnet" "eu-west-1c-public" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.19.24.0/21"
	availability_zone = "eu-west-1c"
}

# Routing table for public subnets

resource "aws_route_table" "eu-west-1-public" {
	vpc_id = "${aws_vpc.default.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.default.id}"
	}
}

resource "aws_route_table_association" "eu-west-1a-public" {
	subnet_id = "${aws_subnet.eu-west-1a-public.id}"
	route_table_id = "${aws_route_table.eu-west-1-public.id}"
}

resource "aws_route_table_association" "eu-west-1b-public" {
	subnet_id = "${aws_subnet.eu-west-1b-public.id}"
	route_table_id = "${aws_route_table.eu-west-1-public.id}"
}

resource "aws_route_table_association" "eu-west-1c-public" {
	subnet_id = "${aws_subnet.eu-west-1c-public.id}"
	route_table_id = "${aws_route_table.eu-west-1-public.id}"
}

# Private subsets
resource "aws_subnet" "eu-west-1a-private" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.19.40.0/21"
	availability_zone = "eu-west-1a"
}

resource "aws_subnet" "eu-west-1b-private" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.19.48.0/21"
	availability_zone = "eu-west-1b"
}

resource "aws_subnet" "eu-west-1c-private" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.19.56.0/21"
	availability_zone = "eu-west-1c"
}

# Routing table for private subnets

resource "aws_route_table" "us-east-1-private" {
	vpc_id = "${aws_vpc.default.id}"

	route {
		cidr_block = "0.0.0.0/0"
		instance_id = "${aws_instance.nat.id}"
	}
}

resource "aws_route_table_association" "eu-west-1a-private" {
	subnet_id = "${aws_subnet.eu-west-1a-private.id}"
	route_table_id = "${aws_route_table.us-east-1-private.id}"
}

resource "aws_route_table_association" "eu-west-1b-private" {
	subnet_id = "${aws_subnet.eu-west-1b-private.id}"
	route_table_id = "${aws_route_table.us-east-1-private.id}"
}

resource "aws_route_table_association" "eu-west-1c-private" {
	subnet_id = "${aws_subnet.eu-west-1c-private.id}"
	route_table_id = "${aws_route_table.us-east-1-private.id}"
}

# NAT instance

resource "aws_security_group" "nat" {
	name = "nat"
	description = "Allow services from the private subnet through NAT"

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		cidr_blocks = ["${aws_subnet.eu-west-1a-private.cidr_block}"]
	}
	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		cidr_blocks = ["${aws_subnet.eu-west-1b-private.cidr_block}"]
	}
	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		cidr_blocks = ["${aws_subnet.eu-west-1c-private.cidr_block}"]
	}
	vpc_id = "${aws_vpc.default.id}"
}

resource "aws_instance" "nat" {
	ami = "${var.aws_nat_ami}"
	availability_zone = "eu-west-1a"
	instance_type = "m3.medium"
	security_groups = ["${aws_security_group.nat.id}"]
	subnet_id = "${aws_subnet.eu-west-1a-public.id}"
	associate_public_ip_address = true
	source_dest_check = false
}

resource "aws_eip" "nat" {
	instance = "${aws_instance.nat.id}"
	vpc = true
}

# Bastion

resource "aws_security_group" "bastion" {
	name = "bastion"
	description = "Allow SSH traffic from the internet"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	vpc_id = "${aws_vpc.default.id}"
}

resource "aws_instance" "bastion" {
	ami = "${var.aws_ubuntu_ami}"
	availability_zone = "eu-west-1a"
	instance_type = "m3.medium"
	security_groups = ["${aws_security_group.bastion.id}"]
	subnet_id = "${aws_subnet.eu-west-1a-public.id}"
}

resource "aws_eip" "bastion" {
	instance = "${aws_instance.bastion.id}"
	vpc = true
}

# default security

resource "aws_security_group" "default" {
	name = "default"
	description = "allowing SSH traffic from all internal networks"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/8"]
	}
	ingress {
		from_port = -1
		to_port = -1
		protocol = "icmp"
		cidr_blocks = ["10.0.0.0/8"]
	}
	vpc_id = "${aws_vpc.default.id}"
}
