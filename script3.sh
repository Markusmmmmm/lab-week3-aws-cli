#!/bin/bash

set -eu

# Variables
region="us-west-2"
vpc_cidr="10.0.0.0/16"
subnet_cidr="10.0.1.0/24"
key_name="bcitkey"
ubuntu_ami="ami-048ac6bc3c08c2f04"
instance_type="t2.micro"

# Create VPC
vpc_id=$(aws ec2 create-vpc --cidr-block $vpc_cidr --query 'Vpc.VpcId' --output text --region $region)
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value=MyVPC --region $region
echo "Created VPC: $vpc_id"
sleep 20


# Enable DNS hostname
aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames Value=true --region us-west-2 --debug
echo "DNS hostnames enabled for VPC: $vpc_id"

# Create public subnet
subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id \
  --cidr-block $subnet_cidr \
  --availability-zone ${region}a \
  --query 'Subnet.SubnetId' \
  --output text --region $region)
aws ec2 create-tags --resources $subnet_id --tags Key=Name,Value=PublicSubnet --region $region
echo "Created Subnet: $subnet_id"

# Create internet gateway
igw_id=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' \
  --output text --region $region)
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region
echo "Created and attached Internet Gateway: $igw_id"

# Create route table
route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id \
  --query 'RouteTable.RouteTableId' \
  --region $region \
  --output text)
echo "Created Route Table: $route_table_id"

# Associate route table with public subnet
aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id --region $region
echo "Associated Route Table with Subnet: $subnet_id"

# Create route to the internet via the internet gateway
aws ec2 create-route --route-table-id $route_table_id \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id --region $region
echo "Created route to the internet via the Internet Gateway."

# Create security group allowing SSH from anywhere
security_group_id=$(aws ec2 create-security-group --group-name MySecurityGroup \
  --description "Allow SSH" --vpc-id $vpc_id --query 'GroupId' \
  --region $region \
  --output text)
aws ec2 authorize-security-group-ingress --group-id $security_group_id \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $region
echo "Created Security Group: $security_group_id"

# Launch an EC2 instance in the public subnet
instance_id=$(aws ec2 run-instances \
  --image-id "$ubuntu_ami" \
  --count 1 \
  --instance-type "$instance_type" \
  --key-name "$key_name" \
  --security-group-ids "$security_group_id" \
  --subnet-id "$subnet_id" \
  --associate-public-ip-address \
  --query 'Instances[0].InstanceId' \
  --output text --region $region)
echo "Launched EC2 Instance: $instance_id"

# Wait for the EC2 instance to be in running state
aws ec2 wait instance-running --instance-ids "$instance_id" --region $region
echo "Instance $instance_id is now running."

# Get the public IP address of the EC2 instance
public_ip=$(aws ec2 describe-instances --instance-ids "$instance_id" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region $region)

# Write instance data to a file
echo "Instance ID: $instance_id" > instance_data
echo "Public IP: $public_ip" >> instance_data
echo "Instance details written to 'instance_data'."

# Output the public IP address for SSH connection
echo "Connect to your instance using: ssh -i <path-to-private-key> ubuntu@$public_ip"

# Write infrastructure data to a file
echo "vpc_id=${vpc_id}" > infrastructure_data
echo "subnet_id=${subnet_id}" >> infrastructure_data
echo "security_group_id=${security_group_id}" >> infrastructure_data
echo "instance_id=${instance_id}" >> infrastructure_data
