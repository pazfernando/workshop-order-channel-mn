provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  effective_name = var.resource_prefix != "" ? "${var.resource_prefix}-${var.stack_name}" : var.stack_name
  name_slug      = trim(replace(lower(local.effective_name), "/[^a-z0-9-]/", "-"), "-")
  short_name     = length(local.name_slug) <= 24 ? local.name_slug : "${substr(local.name_slug, 0, 15)}-${substr(sha256(local.name_slug), 0, 8)}"

  service_name           = "order-satellite-service"
  service_namespace      = "observability-demo"
  deployment_environment = "dev"
  log_group_name         = "/ecs/${local.name_slug}"
  public_azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs    = ["10.42.0.0/24", "10.42.1.0/24"]

  otlp_base_endpoint = var.export_strategy == "collector" ? trimspace(var.collector_endpoint) : trimspace(var.direct_endpoint)
  otlp_traces_endpoint = var.export_strategy == "collector" ? (
    trimspace(var.collector_traces_endpoint)
  ) : trimspace(var.direct_traces_endpoint)
  otlp_metrics_endpoint = var.export_strategy == "collector" ? (
    trimspace(var.collector_metrics_endpoint)
  ) : trimspace(var.direct_metrics_endpoint)
  has_otlp_endpoint = local.otlp_base_endpoint != "" || local.otlp_traces_endpoint != "" || local.otlp_metrics_endpoint != ""
  otlp_enabled      = var.instrumentation_mode == "javaagent" && local.has_otlp_endpoint

  base_environment = [
    {
      name  = "ORDER_API_BASE_URL"
      value = var.order_api_base_url
    },
    {
      name  = "OTEL_SERVICE_NAME"
      value = local.service_name
    },
    {
      name  = "OTEL_RESOURCE_ATTRIBUTES"
      value = "service.namespace=${local.service_namespace},deployment.environment=${local.deployment_environment},service.version=${var.app_version}"
    },
    {
      name  = "OTEL_PROPAGATORS"
      value = "tracecontext,baggage"
    },
    {
      name  = "OTEL_TRACES_SAMPLER"
      value = "parentbased_traceidratio"
    },
    {
      name  = "OTEL_TRACES_SAMPLER_ARG"
      value = "0.5"
    },
    {
      name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
      value = "http/protobuf"
    },
    {
      name  = "OTEL_TRACES_EXPORTER"
      value = local.otlp_enabled ? "otlp" : "none"
    },
    {
      name  = "OTEL_METRICS_EXPORTER"
      value = local.otlp_enabled ? "otlp" : "none"
    },
    {
      name  = "OTEL_LOGS_EXPORTER"
      value = "none"
    },
    {
      name  = "OTEL_METRIC_EXPORT_INTERVAL"
      value = "10000"
    }
  ]

  javaagent_environment = var.instrumentation_mode == "javaagent" ? [
    {
      name  = "JAVA_TOOL_OPTIONS"
      value = "-javaagent:/otel/opentelemetry-javaagent.jar"
    }
  ] : []

  otlp_base_environment = local.otlp_base_endpoint != "" ? [
    {
      name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
      value = local.otlp_base_endpoint
    }
  ] : []

  otlp_trace_environment = local.otlp_traces_endpoint != "" ? [
    {
      name  = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
      value = local.otlp_traces_endpoint
    }
  ] : []

  otlp_metric_environment = local.otlp_metrics_endpoint != "" ? [
    {
      name  = "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"
      value = local.otlp_metrics_endpoint
    }
  ] : []

  container_environment = concat(
    local.base_environment,
    local.javaagent_environment,
    local.otlp_base_environment,
    local.otlp_trace_environment,
    local.otlp_metric_environment
  )

  common_tags = {
    Application     = local.service_name
    Environment     = local.deployment_environment
    ManagedBy       = "terraform"
    ObservabilityID = "order-satellite-demo"
    ResourcePrefix  = var.resource_prefix
    System          = "order-processing-system"
  }
}

resource "aws_vpc" "app" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = local.name_slug
  })
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = merge(local.common_tags, {
    Name = local.name_slug
  })
}

resource "aws_subnet" "public" {
  count = length(local.public_azs)

  vpc_id                  = aws_vpc.app.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.public_azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_slug}-public-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_slug}-public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_ecr_repository" "app" {
  name         = "${local.name_slug}/app"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days

  tags = local.common_tags
}

resource "aws_ecs_cluster" "app" {
  name = local.name_slug

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "task_execution" {
  name = "${local.short_name}-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${local.short_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_security_group" "load_balancer" {
  name        = "${local.short_name}-alb"
  description = "Allow HTTP access to the order satellite load balancer"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "service" {
  name        = "${local.short_name}-svc"
  description = "Allow load balancer traffic to the order satellite service"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_lb" "app" {
  name               = local.short_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = aws_subnet.public[*].id

  tags = local.common_tags
}

resource "aws_lb_target_group" "app" {
  name        = local.short_name
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.app.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.name_slug
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image_uri
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = local.container_environment

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name            = local.name_slug
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.service.id]
    subnets          = aws_subnet.public[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution,
    aws_lb_listener.http
  ]

  tags = local.common_tags
}
