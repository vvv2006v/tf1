provider "aws" {
  #  region = "eu-west-3"
  region = "us-east-1"
}

resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}
resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-main-rtb"
    }
}


module "myapp-subnet-1a" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block1
    avail_zone = var.avail_zone1
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.myapp-vpc.id
    env_suffix = "a"
}
/*
module "myapp-subnet-1b" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block2
    avail_zone = var.avail_zone2
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.myapp-vpc.id
    env_suffix = "b"
   
}
module "myapp-subnet-1c" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block3
    avail_zone = var.avail_zone3
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.myapp-vpc.id
    env_suffix = "c"
}
*/

module "myapp-server" {
    source = "./modules/webserver"
    vpc_id = aws_vpc.myapp-vpc.id
    my_ip = var.my_ip
    env_prefix = var.env_prefix
    image_name = var.image_name
    public_key_location = var.public_key_location
    instance_type = var.instance_type
    subnet_id = module.myapp-subnet-1a.subnet.id
    avail_zone = var.avail_zone
}
/*
resource "aws_ecs_cluster" "my_cluster" {
  name = "${var.env_prefix}-cluster" 
}

resource "aws_ecs_task_definition" "my_task" {
  family                   = "${var.env_prefix}-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.env_prefix}-task",
      "image": "nginx:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${aws_iam_role.my_ecs_TaskExecutionRole.arn}"
}


resource "aws_iam_role" "my_ecs_TaskExecutionRole" {
  name               = "${var.env_prefix}_ecs_TaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "my_ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.my_ecs_TaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



resource "aws_alb" "my_application_load_balancer" {
  name               = "${var.env_prefix}-lb-tf" # Naming our load balancer
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.my_subnet_a.id}",
    "${aws_default_subnet.my_subnet_b.id}",
    "${aws_default_subnet.my_subnet_c.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.my_load_balancer_security_group.id}"]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "my_load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name        = "${var.env_prefix}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.my_vpc.id}" # Referencing the default VPC
}

resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = "${aws_alb.my_application_load_balancer.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.my_target_group.arn}" # Referencing our tagrte group
  }
}




resource "aws_ecs_service" "my_service" {
  name            = "${var.env_prefix}-service"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.my_cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.my_task.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Setting the number of containers to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.my_target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.my_task.family}"
    container_port   = 80 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.my_subnet_a.id}", "${aws_default_subnet.my_subnet_b.id}", "${aws_default_subnet.my_subnet_c.id}"]
    assign_public_ip = true                                                # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.my_service_security_group.id}"] # Setting the security group
  }
}


resource "aws_security_group" "my_service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.my_load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
*/


