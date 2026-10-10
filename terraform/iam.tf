# ECSタスク用のIAMロール。
#
# 重要（ADR-0006）: ロールは必ず /platform/<env>/ パス配下に作る。
# デプロイロールのIAM権限がこのパスで絞られているため、
# パスを外すと apply が AccessDenied で失敗する。
#
# またアタッチできるポリシーも
#   arn:aws:iam::aws:policy/service-role/*
#   arn:aws:iam::<account>:policy/platform/<env>/*
# に限定されている（AdministratorAccess のアタッチを防ぐため）。

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # 他アカウント・他サービスからの混乱した代理人を防ぐ
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# --- タスク実行ロール（ECSエージェントが使う） --------------------------------
# ECRからのpull、CloudWatch Logsへの書き込み、Secrets Managerからの値取得

resource "aws_iam_role" "execution" {
  name = "${local.name}-exec"
  path = "/platform/${var.env}/"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = {
    Name = "${local.name}-exec"
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- タスクロール（アプリ自身が使う） ----------------------------------------
# 現状のサンプルアプリはAWSリソースを使わないため、権限は持たせない。
# 必要になった時点で、このロールにポリシーを足す

resource "aws_iam_role" "task" {
  name = "${local.name}-task"
  path = "/platform/${var.env}/"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = {
    Name = "${local.name}-task"
  }
}
