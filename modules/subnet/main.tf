resource "aws_subnet" "myapp-subnet-1" {
    count = length(var.avail_zone)
    vpc_id = var.vpc_id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone[count.index]
    tags = {
        Name = "${var.env_prefix}-subnet-${var.env_suffix}"[count.index]
    }
}

output "aws_subnet_id" {
  value = aws_subnet.myapp-subnet.id
}
