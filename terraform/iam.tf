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

  # ポリシーのアタッチは aws_iam_role_policy_attachment で管理するため、
  # ロール側の managed_policy_arns は見ない。
  #
  # これを指定しないと、refresh時に実態の値（アタッチ済みのポリシー）が
  # 入って毎回ドリフトとして報告される。
  # 実機のドリフト検知で stage / prod の両方で誤検知が出ていた（ADR-0012の補足）。
  lifecycle {
    ignore_changes = [managed_policy_arns]
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
