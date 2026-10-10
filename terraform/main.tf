# ADR-0007: アプリのデプロイもTerraformで行う。
# イメージのdigestをvarで渡し、タスク定義とサービスを更新する。
#
# デプロイツールとTerraformが同じタスク定義を書き換える構成にしないのは、
# 恒久的なドリフトが発生してドリフト検知（ADR-0012）が機能しなくなるため。

resource "aws_cloudwatch_log_group" "app" {
  # 命名規約: /ecs/<service>-<app>-<env>
  # platform-infra のIAMポリシーがこの形を前提にしている
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/ecs/${local.name}"
  }
}

# ---------------------------------------------------------------------------
# ALB（ADR-0013）
#
# ALBは3環境で共有されており、パスで振り分ける。
# ALBはパスの書き換えができないため、アプリ側が接頭辞を認識する
# （SERVER_SERVLET_CONTEXT_PATH として実行時に注入する）。
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "app" {
  name        = local.name
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  health_check {
    enabled = true
    # パス接頭辞の配下にヘルスチェックがある。
    # 接頭辞を忘れると全タスクがunhealthyになる
    path                = "${local.path_prefix}/actuator/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # デプロイ時の切り替えを速くする（Springの起動は遅いため、
  # 登録解除の待ち時間を短くしておく）
  deregistration_delay = 30

  tags = {
    Name = local.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = local.listener_arn

  # 優先度は platform-infra が採番した値を使う（ADR-0013）。
  # 自前採番すると3環境×複数アプリで衝突する
  priority = local.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = [local.path_prefix, "${local.path_prefix}/*"]
    }
  }

  tags = {
    Name = local.name
  }
}

# ---------------------------------------------------------------------------
# ECS
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "app" {
  # 命名規約: <service>-<app>-<env>
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = local.image
      essential = true

      portMappings = [
        {
          containerPort = local.container_port
          protocol      = "tcp"
        }
      ]

      # ADR-0005の要点:
      #   環境ごとの差分はすべてここから注入する。
      #   イメージには一切焼き込まない。
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.env
        },
        {
          name  = "SERVER_SERVLET_CONTEXT_PATH"
          value = local.path_prefix
        },
        {
          name  = "APP_COMMIT_SHA"
          value = var.commit_sha
        }
      ]

      # 秘密情報はここで Secrets Manager / SSM SecureString から注入する。
      # イメージにもタスク定義の平文にも入れない
      secrets = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  # platform-infra のIAMが aws:RequestTag/Environment で
  # RegisterTaskDefinition を絞っているため、タグは必須。
  # provider の default_tags で付与されるが、明示もしておく
  tags = {
    Name = local.name
  }
}

resource "aws_ecs_service" "app" {
  name            = local.name
  cluster         = local.cluster_name
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = local.subnet_ids
    security_groups = [local.security_group_id]
    # ADR-0013: NAT Gatewayを作らないため、パブリックIPを付与して
    # ECRからイメージを取得する。本番想定ではない
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  # ADR-0007: applyの失敗時の挙動を明示する。
  # タイムアウトを待つのではなく、ECS側で自動ロールバックさせる
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Springの起動が遅いため、ヘルスチェックの猶予を与える
  health_check_grace_period_seconds = 120

  # apply がサービスの安定を待つ。デプロイ完了の判定を自前で書かずに済む
  wait_for_steady_state = true

  tags = {
    Name = local.name
  }

  # ルールが先に無いとALBからトラフィックが来ない
  depends_on = [aws_lb_listener_rule.app]
}
