# Create #1 vpc in eu-west-1
resource "aws_vpc" "vpc_master" {
  provider             = aws.region-master
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "master-vpc-jenkins"
  }
}

#Create #2 vpc in eu-west-2
resource "aws_vpc" "vpc_worker_paris" {
  provider             = aws.region-worker
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "worker-vpc-jenkins"
  }
}

#Create IGW for #1 vpc
resource "aws_internet_gateway" "igw" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
}

#Create IGW for #2 vpc
resource "aws_internet_gateway" "igw-paris" {
  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_worker_paris.id
}

#Obtains AZs from eu-west-1 region
data "aws_availability_zones" "azs" {
  provider = aws.region-master
  state    = "available"
}

#Create #1 subnet for #1 vpc
resource "aws_subnet" "subnet_1" {
  provider          = aws.region-master
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.1.0/24"
}

#Create #2 subnet for #1 vpc
resource "aws_subnet" "subnet_2" {
  provider          = aws.region-master
  availability_zone = element(data.aws_availability_zones.azs.names, 1)
  vpc_id            = aws_vpc.vpc_master.id
  cidr_block        = "10.0.2.0/24"
}

#Create #1 subnet for #2 vpc
resource "aws_subnet" "subnet_1_paris" {
  provider   = aws.region-worker
  vpc_id     = aws_vpc.vpc_worker_paris.id
  cidr_block = "192.168.1.0/24"
}

#Initiate Peering connection request from eu-west-1
resource "aws_vpc_peering_connection" "euwest1-euwest2" {
  provider    = aws.region-master
  peer_vpc_id = aws_vpc.vpc_worker_paris.id
  vpc_id      = aws_vpc.vpc_master.id
  peer_region = var.region-worker
}

#Accept VPC peering request in eu-west-2 from eu-west-1
resource "aws_vpc_peering_connection_accepter" "accept_peering" {
  provider                  = aws.region-worker
  vpc_peering_connection_id = aws_vpc_peering_connection.euwest1-euwest2.id
  auto_accept               = true
}

#Create routeTable in eu-west-1
resource "aws_route_table" "internet_route" {
  provider = aws.region-master
  vpc_id   = aws_vpc.vpc_master.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  route {
    cidr_block                = "192.168.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.euwest1-euwest2.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Master-Region-RT"
  }
}

#Overwrite default route table of VPC (Master) with our route table entries
resource "aws_main_route_table_association" "set-master-default-rt-assoc" {
  provider       = aws.region-master
  vpc_id         = aws_vpc.vpc_master.id
  route_table_id = aws_route_table.internet_route.id
}

#Create routeTable in eu-west-2
resource "aws_route_table" "internet_route_paris" {
  provider = aws.region-worker
  vpc_id   = aws_vpc.vpc_worker_paris.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-paris.id
  }
  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.euwest1-euwest2.id
  }
  lifecycle {
    ignore_changes = all
  }
  tags = {
    Name = "Worker-Region-RT"
  }
}

#Overwrite default route table of VPC (Worker) with our route table entries
resource "aws_main_route_table_association" "set-worker-default-rt-assoc" {
  provider       = aws.region-worker
  vpc_id         = aws_vpc.vpc_worker_paris.id
  route_table_id = aws_route_table.internet_route_paris.id
}